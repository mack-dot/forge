#!/usr/bin/env python3
"""Independent verifier of `evidence.wal` (and optionally `ledger.wal`). Python 3 stdlib only.

FINITE TEST tool. Nothing here is a proof. This file shares NO code with the Rust verifier
(`mcp-proxy verify-evidence`). It reads the formats from the documentation at the top of
`src/mcp_proxy/evidence.rs` and `src/mcp_proxy/ledger.rs`, recomputes every frame check and every
chain value with `hashlib`, and calls `/usr/bin/ssh-keygen -Y verify` itself for every signature.
When the two verifiers disagree on a file, that is a finding.

    python3 tests/mcp_proxy/verify_independent.py EVIDENCE.wal --allowed-signers FILE
            [--identity NAME] [--ledger LEDGER.wal] [--ledger-ahead-ok] [--quiet]

Checks on `evidence.wal`:
  - the magic; every frame: type 1 or 2, length rule, 8-byte frame check;
  - RECORD indexes 1, 2, 3, ... in file order; SIGNATURE indexes 1, 2, 3, ... in file order; the signature of
    record i comes after record i; exactly one signature per record; no torn tail; at least one record;
  - every chain link from chain_0; names are 1..32 bytes of UTF-8 with zero padding and no NUL; known verdicts;
    epochs never decrease; post == pre for every blocked verdict; the armor shape;
  - every signature: `ssh-keygen -Y verify -f FILE -I NAME -n forge-airlock-evidence -s SIG`, chain hex on stdin;
  - commit continuity (CONTRACT3): the COMMITTED records have epochs 1, 2, 3, ... (no gap, no repeat);
    pre of commit 1 == the ledger genesis hash; pre of commit k+1 == post of commit k; every other record has
    pre == post == the post of the latest earlier commit (or genesis) and epoch == that commit's epoch (or 0).
With --ledger: the ledger chain is recomputed (magic, length and its complement, record check, epoch + 1,
pre = previous post, post recomputed, tool length, no repeated request id digest), and each COMMITTED receipt is
compared with the ledger record of its epoch (pre, post, tool field). A ledger record with no COMMITTED receipt
fails, unless --ledger-ahead-ok (the documented crash window before the start-up recovery). A receipt epoch
above the ledger head fails (the ledger was rolled back or replaced).

Output: one line per record (unless --quiet), `counts={...}` (JSON, verdict -> number), then
`VERIFIED records=<n> signatures=<n> chain=OK continuity=OK [ledger=OK]` with exit 0, or
`FAILED at=<index> <reason>` with exit 1. Usage error: exit 2.
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

SSH_KEYGEN = '/usr/bin/ssh-keygen'
NAMESPACE = 'forge-airlock-evidence'
MAGIC = b'forge-airlock-evidence-wal-v1\n'
FRAME_TAG = b'forge-airlock-evidence-frame-v1'
CHAIN_TAG = b'forge-airlock-evidence-v1'
CHAIN0 = hashlib.sha256(b'forge-airlock-evidence-genesis-v1').digest()
LEDGER_GENESIS = hashlib.sha256(b'forge-airlock-ledger-genesis-v1').digest()[:16]
VERDICTS = {1: 'COMMITTED', 2: 'BLOCKED_CAS', 3: 'BLOCKED_DUPLICATE', 4: 'BLOCKED_POLICY', 5: 'BLOCKED_SUBCAP',
            6: 'READ_ALLOWED', 7: 'READ_DROPPED', 8: 'BLOCKED_MALFORMED'}
BLOCKED = {2, 3, 4, 5, 8}
ARMOR_HEAD = b'-----BEGIN SSH SIGNATURE-----\n'
ARMOR_TAIL = b'-----END SSH SIGNATURE-----\n'
REC_LEN = 113
RECORD_FRAME_LEN = 8 + REC_LEN + 32

L_MAGIC = b'FAL1'
L_FIXED = 8 + 16 + 16 + 32 + 32 + 2
L_MAX_TOOL = 1024


class Fail(Exception):
    def __init__(self, at, why):
        Exception.__init__(self, why)
        self.at, self.why = at, why


def be(b):
    return int.from_bytes(b, 'big')


def frame_check(t, payload):
    return hashlib.sha256(FRAME_TAG + bytes([t]) + len(payload).to_bytes(4, 'big') + payload).digest()[:8]


def name_field(b):
    """1..32 bytes of UTF-8, no NUL, then zero padding. -> text or None."""
    n = b.find(b'\0')
    body, pad = (b, b'') if n < 0 else (b[:n], b[n:])
    if not body or any(pad) or b'\0' in body:
        return None
    try:
        return body.decode('utf-8')
    except UnicodeDecodeError:
        return None


def receipt_tool_field(tool_bytes):
    """The rule of evidence.rs: 1..32 bytes of UTF-8 with no NUL stay; anything else -> first 32 hex of SHA-256."""
    try:
        tool_bytes.decode('utf-8')
        ok = 1 <= len(tool_bytes) <= 32 and b'\0' not in tool_bytes
    except UnicodeDecodeError:
        ok = False
    return tool_bytes.decode('utf-8') if ok else hashlib.sha256(tool_bytes).hexdigest()[:32]


def parse_frames(data):
    if len(data) < len(MAGIC) or data[:len(MAGIC)] != MAGIC:
        raise Fail(0, 'bad magic')
    i, out = len(MAGIC), []
    while i < len(data):
        if len(data) - i < 5:
            raise Fail(0, 'torn tail: %d byte(s) of a frame header at offset %d' % (len(data) - i, i))
        t, n = data[i], be(data[i + 1:i + 5])
        if t == 1:
            if n != RECORD_FRAME_LEN:
                raise Fail(0, 'RECORD frame at offset %d has length %d, want %d' % (i, n, RECORD_FRAME_LEN))
        elif t == 2:
            if not (9 <= n <= 8 + 4096):
                raise Fail(0, 'SIGNATURE frame at offset %d has length %d' % (i, n))
        else:
            raise Fail(0, 'unknown frame type %d at offset %d' % (t, i))
        end = i + 5 + n + 8
        if end > len(data):
            raise Fail(0, 'torn tail: frame at offset %d needs %d bytes, %d present' % (i, end - i, len(data) - i))
        payload, chk = data[i + 5:i + 5 + n], data[i + 5 + n:end]
        if frame_check(t, payload) != chk:
            raise Fail(0, 'frame check mismatch at offset %d' % i)
        out.append((t, payload))
        i = end
    return out


def order(frames):
    """-> list of [record(113), chain(32), armor or None]. Applies the order rules."""
    recs, nsig = [], 0
    for t, p in frames:
        idx = be(p[:8])
        if t == 1:
            if idx != len(recs) + 1:
                raise Fail(len(recs) + 1, 'RECORD index %d out of order (want %d)' % (idx, len(recs) + 1))
            recs.append([p[8:8 + REC_LEN], p[8 + REC_LEN:], None])
        else:
            if idx != nsig + 1:
                raise Fail(nsig + 1, 'SIGNATURE index %d out of order (want %d)' % (idx, nsig + 1))
            if idx > len(recs):
                raise Fail(idx, 'SIGNATURE of record %d comes before its RECORD frame' % idx)
            recs[idx - 1][2] = p[8:]
            nsig += 1
    return recs


def ssh_verify(allowed, ident, tmpdir, idx, armor, chain):
    sp = os.path.join(tmpdir, 'r%d.sig' % idx)
    fd = os.open(sp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as f:
        f.write(armor)
    try:
        p = subprocess.run([SSH_KEYGEN, '-Y', 'verify', '-f', allowed, '-I', ident, '-n', NAMESPACE, '-s', sp],
                           input=chain.hex().encode(), capture_output=True, env={}, cwd='/', timeout=60)
    finally:
        os.remove(sp)
    if p.returncode != 0:
        msg = (p.stderr or p.stdout).decode('utf-8', 'replace').strip().splitlines()
        return 'ssh-keygen -Y verify exit %d: %s' % (p.returncode, msg[-1] if msg else '')
    return None


def parse_ledger(path):
    """-> list of dicts (epoch, pre, post, rid_digest, tool). Raises Fail(0, ...) on any damage.
    A torn last record (fewer bytes than one record, starting like a record) is ignored, as `read_head` does."""
    with open(path, 'rb') as f:
        data = f.read()
    i, out, head, seen = 0, [], LEDGER_GENESIS, set()
    while i < len(data):
        left = data[i:]
        if len(left) < 12:
            if L_MAGIC.startswith(left[:4]):
                break  # torn tail
            raise Fail(0, 'ledger: bad bytes at offset %d' % i)
        if left[:4] != L_MAGIC:
            raise Fail(0, 'ledger: bad magic at offset %d' % i)
        n, nn = be(left[4:8]), be(left[8:12])
        if n ^ 0xFFFFFFFF != nn:
            raise Fail(0, 'ledger: length complement mismatch at offset %d' % i)
        if not (L_FIXED + 1 <= n <= L_FIXED + L_MAX_TOOL):
            raise Fail(0, 'ledger: body length %d out of range at offset %d' % (n, i))
        total = 12 + n + 32
        if len(left) < total:
            break  # torn tail (header agrees with a record start)
        rec = left[:total]
        body = rec[:12 + n]
        if hashlib.sha256(len(b'forge-airlock-ledger-record-v1').to_bytes(4, 'big') + b'forge-airlock-ledger-record-v1'
                          + len(body).to_bytes(4, 'big') + body).digest() != rec[12 + n:]:
            raise Fail(0, 'ledger: record check mismatch at offset %d' % i)
        epoch, pre, post = be(rec[12:20]), rec[20:36], rec[36:52]
        rid_d, args_d, tl = rec[52:84], rec[84:116], be(rec[116:118])
        if tl < 1 or 106 + tl != n:
            raise Fail(0, 'ledger: tool length %d does not match body length %d' % (tl, n))
        tool = rec[118:118 + tl]
        if epoch != len(out) + 1:
            raise Fail(0, 'ledger: record %d has epoch %d' % (len(out) + 1, epoch))
        if pre != head:
            raise Fail(0, 'ledger: record %d pre is not the previous head' % epoch)

        def fr(x):
            return len(x).to_bytes(4, 'big') + x
        want = hashlib.sha256(fr(b'forge-airlock-ledger-v1') + fr(pre) + fr(epoch.to_bytes(8, 'big')) + fr(rid_d)
                              + fr(tool) + fr(args_d)).digest()[:16]
        if want != post:
            raise Fail(0, 'ledger: record %d post does not match the recomputed state hash' % epoch)
        if rid_d in seen:
            raise Fail(0, 'ledger: record %d repeats a request id digest' % epoch)
        seen.add(rid_d)
        out.append({'epoch': epoch, 'pre': pre, 'post': post, 'tool': tool})
        head = post
        i += total
    return out


def allowed_note(path):
    n = 0
    with open(path, 'rb') as f:
        for line in f.read().decode('utf-8', 'replace').splitlines():
            s = line.strip()
            if s and not s.startswith('#'):
                n += 1
    return n


def run(wal, allowed, ident, ledger, ledger_ahead_ok, quiet):
    counts = {}
    nrec = 0
    try:
        try:
            keys = allowed_note(allowed)
        except OSError as e:
            raise Fail(0, 'cannot read allowed signers file: %s' % e)
        print('trust root: the allowed signers file %s (%d key line(s)%s)' % (
            allowed, keys, '; MORE THAN ONE KEY IS TRUSTED' if keys > 1 else ''))
        try:
            with open(wal, 'rb') as f:
                data = f.read()
        except OSError as e:
            raise Fail(0, 'cannot open %s: %s' % (wal, e))
        recs = order(parse_frames(data))
        if not recs:
            raise Fail(0, 'no records (nothing to verify is not a pass)')
        tmpdir = tempfile.mkdtemp(prefix='vind-')
        try:
            chain, prev_epoch = CHAIN0, 0
            last_commit_epoch, last_commit_post = 0, LEDGER_GENESIS
            commits = []
            for k, (rec, stored_chain, armor) in enumerate(recs):
                idx = k + 1
                epoch, ts = be(rec[0:8]), be(rec[8:16])
                agent, tool = name_field(rec[16:48]), name_field(rec[48:80])
                pre, post, v = rec[80:96], rec[96:112], rec[112]
                vname = VERDICTS.get(v)
                if not quiet:
                    print('#%d epoch=%d ts=%d agent=%s tool=%s pre=%s post=%s verdict=%s' % (
                        idx, epoch, ts, agent, tool, pre.hex(), post.hex(), vname or '?%d' % v))
                nxt = hashlib.sha256(CHAIN_TAG + chain + rec).digest()
                if nxt != stored_chain:
                    raise Fail(idx, 'chain link mismatch')
                if agent is None or tool is None:
                    raise Fail(idx, 'agent or tool field is not 1..32 bytes of UTF-8 with zero padding')
                if vname is None:
                    raise Fail(idx, 'unknown verdict %d' % v)
                if epoch < prev_epoch:
                    raise Fail(idx, 'epoch %d decreases (previous %d)' % (epoch, prev_epoch))
                if v in BLOCKED and pre != post:
                    raise Fail(idx, 'blocked verdict with post != pre')
                if v == 1:
                    if epoch != last_commit_epoch + 1:
                        raise Fail(idx, 'commit continuity: COMMITTED epoch %d, want %d' % (epoch, last_commit_epoch + 1))
                    if pre != last_commit_post:
                        raise Fail(idx, 'commit continuity: COMMITTED pre %s != post of the previous commit (or genesis) %s'
                                   % (pre.hex(), last_commit_post.hex()))
                    last_commit_epoch, last_commit_post = epoch, post
                    commits.append((idx, epoch, pre, post, tool))
                else:
                    if not (pre == post == last_commit_post):
                        raise Fail(idx, 'commit continuity: %s record pre/post %s/%s != head %s' % (
                            vname, pre.hex(), post.hex(), last_commit_post.hex()))
                    if epoch != last_commit_epoch:
                        raise Fail(idx, 'commit continuity: %s record epoch %d != head epoch %d' % (vname, epoch, last_commit_epoch))
                if armor is None:
                    raise Fail(idx, 'record has no signature')
                if not (armor.startswith(ARMOR_HEAD) and armor.endswith(ARMOR_TAIL)):
                    raise Fail(idx, 'signature armor shape is wrong')
                err = ssh_verify(allowed, ident, tmpdir, idx, armor, nxt)
                if err:
                    raise Fail(idx, err)
                chain, prev_epoch = nxt, epoch
                counts[vname] = counts.get(vname, 0) + 1
                nrec = idx
        finally:
            shutil.rmtree(tmpdir, ignore_errors=True)
        ledger_word = ''
        if ledger:
            try:
                lrecs = parse_ledger(ledger)
            except OSError as e:
                raise Fail(0, 'cannot read ledger %s: %s' % (ledger, e))
            for idx, epoch, pre, post, tool in commits:
                if epoch > len(lrecs):
                    raise Fail(idx, 'ledger cross-check: receipt epoch %d is above the ledger head %d' % (epoch, len(lrecs)))
                lr = lrecs[epoch - 1]
                if lr['pre'] != pre or lr['post'] != post:
                    raise Fail(idx, 'ledger cross-check: receipt epoch %d pre/post differ from the ledger record' % epoch)
                if receipt_tool_field(lr['tool']) != tool:
                    raise Fail(idx, 'ledger cross-check: receipt epoch %d tool %r != ledger tool %r' % (epoch, tool, lr['tool']))
            if len(lrecs) > len(commits) and not ledger_ahead_ok:
                raise Fail(nrec + 1, 'ledger cross-check: ledger has %d record(s), evidence has %d COMMITTED receipt(s)'
                           % (len(lrecs), len(commits)))
            ledger_word = ' ledger=OK(records=%d,commits=%d)' % (len(lrecs), len(commits))
        print('counts=%s' % json.dumps(counts, sort_keys=True))
        print('final_chain=%s' % chain.hex())
        print('VERIFIED records=%d signatures=%d chain=OK continuity=OK%s' % (nrec, nrec, ledger_word))
        return 0
    except Fail as f:
        print('counts=%s' % json.dumps(counts, sort_keys=True))
        print('FAILED at=%d %s' % (f.at, f.why))
        return 1


def main(argv):
    usage = ('usage: verify_independent.py EVIDENCE.wal --allowed-signers FILE [--identity NAME] [--ledger FILE] '
             '[--ledger-ahead-ok] [--quiet]\n')
    pos, opts, flags = [], {}, set()
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ('--allowed-signers', '--identity', '--ledger'):
            if i + 1 >= len(argv) or a in opts:
                sys.stderr.write(usage)
                return 2
            opts[a] = argv[i + 1]
            i += 2
        elif a in ('--ledger-ahead-ok', '--quiet'):
            flags.add(a)
            i += 1
        elif a.startswith('-'):
            sys.stderr.write(usage)
            return 2
        else:
            pos.append(a)
            i += 1
    if len(pos) != 1 or '--allowed-signers' not in opts:
        sys.stderr.write(usage)
        return 2
    return run(pos[0], os.path.abspath(opts['--allowed-signers']), opts.get('--identity', 'forge-airlock'), opts.get('--ledger'),
               '--ledger-ahead-ok' in flags, '--quiet' in flags)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))

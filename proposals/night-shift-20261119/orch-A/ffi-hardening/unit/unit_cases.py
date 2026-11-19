"""A23: argument-shape unit cases for read/write/close/open_in. Runs harness_orig and harness_patched
(both link basis_ffi.c compiled with -O2 -Dmain=basis_main) and compares each to a Python transcription of
the model clause (fsFFIScript.sml 265-277, 307-327, 333-348, 351-362; basis_ffiScript.sml:19-49), with the
model file system = STD_streams only (fd 0 stdin ReadMode, fd 1/2 WriteMode, no files).
FINITE TEST, not a proof. The transcription is UNCHECKED against HOL.
Usage: python3 -I unit_cases.py > unit_results.json
"""
import json, subprocess, sys
G = 8
STDIN = b'HELLO-STDIN'
def be8(v): return (v % 2**64).to_bytes(8, 'big')
def b2(v): return v.to_bytes(2, 'big')
C = []  # (id, fn, clen, conf, alen, buflen, arr)
def case(i, fn, conf, alen, arr, clen=None, buflen=None):
    if clen is None: clen = len(conf)
    if buflen is None: buflen = alen if alen >= 0 else len(arr)
    C.append((i, fn, clen, conf, alen, buflen, arr))
hdr = lambda n, x=0: b2(n) + b2(x)
case('R01-success', 'read', be8(0), 9, hdr(5) + b'\x00' * 5)
case('R02-clen0', 'read', b'', 9, hdr(5) + b'\x00' * 5)
case('R03-clen7', 'read', be8(0)[:7], 9, hdr(5) + b'\x00' * 5)
case('R04-clen9', 'read', be8(0) + b'\x00', 9, hdr(5) + b'\x00' * 5)
case('R05-alen0', 'read', be8(0), 0, b'')
for k in (1, 2, 3): case('R06-alen%d' % k, 'read', be8(0), k, b'\x00\x05\x00'[:k])
case('R07-short-alen4', 'read', be8(0), 4, hdr(5))
case('R08-short-alen8', 'read', be8(0), 8, hdr(5) + b'\x00' * 4)
case('R09-fd-2^32', 'read', be8(2**32), 9, hdr(5) + b'\x00' * 5)
case('R10-fd1-writemode', 'read', be8(1), 9, hdr(5) + b'\x00' * 5)
case('R11-fd99', 'read', be8(99), 9, hdr(5) + b'\x00' * 5)
case('R12-fd-all-ones', 'read', be8(2**64 - 1), 9, hdr(5) + b'\x00' * 5)
case('R13-fd-2^31', 'read', be8(2**31), 9, hdr(5) + b'\x00' * 5)
case('R14-alen-topbit', 'read', be8(0), -1, hdr(5) + b'\x00' * 5)
case('R15-n0', 'read', be8(0), 4, hdr(0))
case('W01-success', 'write', be8(1), 7, hdr(3, 0) + b'abc')
case('W02-clen0', 'write', b'', 7, hdr(3, 0) + b'abc')
case('W03-alen0', 'write', be8(1), 0, b'')
for k in (1, 2, 3): case('W03-alen%d' % k, 'write', be8(1), k, b'\x00\x03\x00'[:k])
case('W04-off-past-end', 'write', be8(1), 8, hdr(1, 5) + b'abcd')
case('W05-n-past-end', 'write', be8(1), 8, hdr(3, 2) + b'abcd')
case('W06-fd-2^32+1', 'write', be8(2**32 + 1), 7, hdr(3, 0) + b'abc')
case('W07-fd0-readmode', 'write', be8(0), 7, hdr(3, 0) + b'abc')
case('W08-alen-topbit', 'write', be8(1), -1, hdr(3, 0) + b'abc')
case('W09-offset', 'write', be8(1), 8, hdr(3, 1) + b'abcd')
case('C01-alen0-U393', 'close', be8(99), 0, b'')
case('C02-clen0', 'close', b'', 1, b'\x05')
case('C03-fd99', 'close', be8(99), 1, b'\x05')
case('C04-fd1-stream', 'close', be8(1), 1, b'\x05')
case('C05-fd-2^32+99', 'close', be8(2**32 + 99), 1, b'\x05')
case('C06-alen-topbit', 'close', be8(99), -1, b'\x05')
case('O01-alen0', 'open_in', b'/nonexistent-a23\x00', 0, b'')
for k in range(1, 9): case('O02-alen%d' % k, 'open_in', b'/nonexistent-a23\x00', k, b'\x07' * k)
case('O03-missing', 'open_in', b'/nonexistent-a23\x00', 9, b'\x07' * 9)
case('O04-no-nul', 'open_in', b'abcd', 9, b'\x07' * 9)
case('O05-devnull', 'open_in', b'/dev/null\x00', 9, b'\x07' * 9)
case('O06-alen-topbit', 'open_in', b'/nonexistent-a23\x00', -1, b'\x07' * 9)


def model(fn, clen, conf, alen, arr):
    """Returns ('final',) or ('error', bytes) or ('success', checker)."""
    L = alen % 2**64  # w2n of the length register
    b = bytearray(arr)
    err = lambda: ('error', bytes([1]) + bytes(b[1:]) if b else bytes(b))
    w82n = int.from_bytes(conf, 'big') if len(conf) == 8 else None
    if fn == 'read':
        if L < 4: return ('final',)
        n = int.from_bytes(b[0:2], 'big')
        if clen != 8 or L - 4 < n or w82n != 0: return err()   # only fd 0 is ReadMode
        return ('success-read', n)
    if fn == 'write':
        if L < 4: return ('final',)
        n, off = int.from_bytes(b[0:2], 'big'), int.from_bytes(b[2:4], 'big')
        if clen != 8 or L - 4 < off or n > L - 4 - off or w82n not in (1, 2): return err()
        return ('success-write', n)
    if fn == 'close':
        if L < 1 or clen != 8: return ('final',)
        return err()  # no File fd is open in the model; 0..2 are UStream (closeFD isFile)
    if fn == 'open_in':
        if L < 9 or 0 not in conf or True:  # no files in the model fs: openFile always fails
            return ('final',) if L == 0 else err()


def judge(m, out, arr, alen):
    if m[0] == 'final':
        return out[0].startswith('SIG') or out[0].startswith('EXIT'), 'model halts'
    if out[0] != 'RET': return False, 'C did not return'
    full = bytes.fromhex(out[1]); g1, body, g2 = full[:G], full[G:-G], full[-G:]
    if g1 != b'\xee' * G or g2 != b'\xee' * G: return False, 'write outside the allocated array'
    if m[0] == 'error': return body == m[1], 'error byte'
    if m[0] == 'success-read':
        n = m[1]; k = int.from_bytes(body[1:3], 'big')
        ok = body[0] == 0 and (k >= 1 if n else k == 0) and k <= min(n, len(STDIN)) and body[3] == arr[3] and \
            body[4:4 + k] == STDIN[:k] and body[4 + k:] == arr[4 + k:]
        return ok, 'read success, k=%d' % k
    if m[0] == 'success-write':
        n = m[1]; k = int.from_bytes(body[1:3], 'big')
        return body[0] == 0 and k <= n and body[3:] == arr[3:], 'write success, k=%d' % k


def run(h):
    lines = []
    for (i, fn, clen, conf, alen, buflen, arr) in C:
        lines.append('%s %s %d %s %d %d %s' % (i, fn, clen, conf.hex() or '-', alen, buflen, arr.hex() or '-'))
    p = subprocess.run([h], input=('\n'.join(lines) + '\n').encode(), capture_output=True, timeout=120)
    res = {}
    for line in p.stdout.decode().splitlines():
        i, o, x = line.split(' ')
        res[i] = (o, x)
    return p.returncode, res


ro, O = run('./harness_orig'); rp, P = run('./harness_patched')
rows, summary = [], {'cases': len(C), 'patched_eq_model': 0, 'orig_eq_model': 0}
for (i, fn, clen, conf, alen, buflen, arr) in C:
    m = model(fn, clen, conf, alen, arr)
    jo, jp = judge(m, O[i], arr, alen), judge(m, P[i], arr, alen)
    summary['patched_eq_model'] += jp[0]; summary['orig_eq_model'] += jo[0]
    rows.append({'id': i, 'model': m[0], 'orig': O[i][0], 'orig_eq_model': jo[0], 'orig_note': jo[1],
                 'patched': P[i][0], 'patched_eq_model': jp[0], 'patched_note': jp[1],
                 'orig_bytes': O[i][1][2 * G:-2 * G] if O[i][0] == 'RET' else None,
                 'patched_bytes': P[i][1][2 * G:-2 * G] if P[i][0] == 'RET' else None})
json.dump({'class': 'TESTED-UNPROVED (finite test; model transcription UNCHECKED)', 'harness_exit':
           {'orig': ro, 'patched': rp}, 'summary': summary, 'rows': rows}, sys.stdout, indent=1)
for r in rows:
    print('%-20s model=%-14s orig=%-5s %-5s patched=%-5s %-5s %s' % (r['id'], r['model'], r['orig'], r['orig_eq_model'],
          r['patched'], r['patched_eq_model'], r['patched_note']), file=sys.stderr)
print(summary, file=sys.stderr)
sys.exit(0 if summary['patched_eq_model'] == len(C) else 1)

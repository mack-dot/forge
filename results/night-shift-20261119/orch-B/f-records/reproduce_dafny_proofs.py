#!/usr/bin/env python3
"""Reproduce the M1-B Dafny proof records from repository sources (night shift 2026-11-19, task f-records).

Python 3 standard library only. It decides nothing by itself about the truth of a theorem: it runs the
pinned Dafny verifier (through a lock script), and it records bytes, exit codes and counts.

Per proof it:
  1. computes the FULL include closure (transitive `include` lines) and stores path + SHA-256 of every file;
  2. checks every copy against its original in the checkout (or says that no original is in the checkout);
  3. runs `dafny verify` with the gate options and a CSV log; stores log, CSV, exit, summary, counts and
     the required (headline) lemma names found in the CSV (a missing name FAILS the record);
  4. runs `dafny audit` over the closure; greps for assume / {:axiom} / @Axiom / bodiless lemma /
     {:verify false} / expect / {:extern} and lists each hit (code or comment);
  5. records the Dafny version (from the lock log), the SHA-256 of the dafny launcher and of z3, the z3
     version, the options, the OS, the machine, the commit and the date.
Optional: `dafny build` for refinement instances (CSV rows that only `build` checks), stored negative
controls, and self-controls of this runner.

Every Dafny process runs through the lock script:  LOCK OWNER WORKDIR LOGFILE TIMEOUT_S <dafny args>.
No absolute home path is stored in this file. Paths come from arguments or the environment:
  --checkout DIR   a clean checkout (default: <this dir>/checkout; make one with
                   `git -C <repo> archive <commit> | tar -x -C <dir>`)
  --dafny PATH     or env DAFNY  (only hashed and compared with the lock log; the lock script runs Dafny)
  --z3 PATH        or env Z3
  --lock PATH      or env DAFNY_LOCK
"""
import argparse, csv, datetime, hashlib, json, os, platform, re, shutil, subprocess, sys, time, urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
PROPOSAL = 'proposals/m1b-mission-20261119/proofs'
OWNER = 'orch-B/f-records'
ESTABLISH_RERUN = 're-ran the verifier'
ESTABLISH_IDENTITY = 'identity only, proof NOT re-run'
GATE_OPTIONS = ['--resource-limit', '1000000', '--verification-time-limit', '0', '--cores', '1',
                '--verify-included-files', '--track-print-effects']
HEX_AXIOM = 'Std.Strings.HexConversion.CharsConsistent'

# Originals in the checkout for the copies the reports call byte-equal (copy path -> checkout path).
ORIG_SPEC = 'spec/refund/RefundSpec.dfy'
ORIG_REFUND = 'impl/Refund.dfy'
ORIG_FINALITY = 'impl/RefundFinality.dfy'
ORIG_EXACT = 'clearing/RefundExact.dfy'
ORIG_DETERMINISM = 'proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy'
ORIG_PROTOCOL = 'proposals/forge2-pillar2-finality-protocol/FinalityProtocol.dfy'
LR = PROPOSAL + '/linked-refund/inputs'
SC = PROPOSAL + '/sink-core/inputs'
ST = PROPOSAL + '/slice-theorem/inputs'

# Digests that a stored report STATES for files with no original in the checkout (identity to a stated value only).
STATED = {
    'transport/FlatCore.dfy': ('a89484e354914ca293286abfdb97376805d4e417a270342db15df4b784a51f4d',
                               'run_check.py and RESULTS.md: the input of the U294 export'),
    'UnicodeRelation.dfy': ('804504ef807d5c67ffaef7e11581ebe523f807c48af069d3c9ff5f5305f91990', 'RESULTS.md (U262 encoder)'),
    'LinkedRefund.dfy': ('0d67b4838e390a336dfec027326a2cb067a7a35fa120af60b94bdfda4d069f34', 'run_check.py PROOF_SHA256'),
    'sink/SinkCore.dfy': ('198474e450db2bc1f255a07c6a6421b38e49285045415835bca16bfacb3601ba', 'review/mutate.py assert (prefix 198474e4)'),
    'SliceTheorem.dfy': ('1d64e8efc76db0191942d62591b6971338bf162ae4559e572e822d223da9cd87', 'G9 report'),
}


def lr_copies(rel):
    m = {'transport/spec/refund/RefundSpec.dfy': ORIG_SPEC, 'transport/impl/Refund.dfy': ORIG_REFUND,
         'transport/clearing/RefundExact.dfy': ORIG_EXACT,
         'transport/proposals/forge2-pillar1-spec-determinism/RefundDeterminism.dfy': ORIG_DETERMINISM}
    return ('repository', m[rel]) if rel in m else None


def sc_copies(rel):
    m = {'spec/refund/RefundSpec.dfy': ORIG_SPEC, 'impl/Refund.dfy': ORIG_REFUND,
         'impl/RefundFinality.dfy': ORIG_FINALITY, 'model/FinalityProtocol.dfy': ORIG_PROTOCOL}
    return ('repository', m[rel]) if rel in m else None


def st_copies(rel):
    m = {'transport/impl/RefundFinality.dfy': ORIG_FINALITY, 'transport/model/FinalityProtocol.dfy': ORIG_PROTOCOL}
    if rel in m:
        return ('repository', m[rel])
    r = lr_copies(rel)
    if r:
        return r
    if rel == 'transport/sink/SinkCore.dfy':
        return ('intra-proposal', SC + '/sink/SinkCore.dfy')
    return None


def st_intra(rel):  # every other slice-theorem file is said to be a copy of the linked-refund file at the same path
    return ('intra-proposal', LR + '/' + rel) if rel != 'SliceTheorem.dfy' else None


LR_REQUIRED = ['LinkedRefund.Assess (correctness)', 'LinkedRefund.UnflattenFlatten', 'LinkedRefund.FlatYieldsOnlyImages',
               'LinkedRefund.ApprovedFlattensToFlat', 'LinkedRefund.Uniqueness', 'LinkedRefund.FlattenInjective',
               'LinkedRefund.WitnessAccepted', 'LinkedRefund.WitnessRejected', 'LinkedRefund.WitnessUnicode',
               'LinkedRefund.WitnessUnique', 'LinkedPost.PostUnique', 'LinkedPost.PostAcceptsAndRejects']
SC_REQUIRED = ['SinkCore.InitRel', 'SinkCore.StepRefinesCommit', 'SinkCore.StepPreservesInv', 'SinkCore.MintKeepsRel',
               'SinkCore.ChainSum', 'SinkCore.RefundSliceShape', 'SinkCore.ZeroAmountRepeats', 'SinkCore.EncInjective']

PROOFS = {
    'linked-refund': dict(root=LR, entry='LinkedRefund.dfy', copies=lr_copies, expected_verified=1489,
                          expected_audit=[HEX_AXIOM], expected_code_hits=[('library/Std/Strings.dfy', '@Axiom')],
                          expected_bodiless=[('library/Std/Strings.dfy', 'CharsConsistent')],
                          required=LR_REQUIRED, instance=True, size='large',
                          record_source='records/m1b-linked-refund-run2.log (1489 verified); RESULTS.md'),
    'linked-refund-no-axiom': dict(root=LR, entry='LinkedRefund.dfy', copies=lr_copies, expected_verified=1486,
                                   derive=[('classic-diff', PROPOSAL + '/linked-refund/review-controls/S3a-remove-hex-module.diff',
                                            'library/Std/Strings.dfy')],
                                   expected_audit=[], expected_code_hits=[], expected_bodiless=[],
                                   required=LR_REQUIRED, instance=True, size='large',
                                   record_source='records/S3a-worker-verify-out.txt (1486 verified); D10 report'),
    'sink-core': dict(root=SC, entry='sink/SinkCore.dfy', copies=sc_copies, expected_verified=56, expected_audit=[],
                      expected_code_hits=[], expected_bodiless=[], required=SC_REQUIRED, instance=True, size='small',
                      record_source='records/orchestrator-verification.csv (56 rows); D7 report'),
    'sink-core-attack': dict(root=SC, entry='sink/Attack.dfy', copies=sc_copies, expected_verified=60,
                             add=[(PROPOSAL + '/sink-core/review/Attack.dfy', 'sink/Attack.dfy')],
                             expected_audit=[], expected_code_hits=[], expected_bodiless=[],
                             required=['Attack.TotalVerifierBreaksIdealMac', 'Attack.IdealMacAtInit', 'Attack.LocalA1Suffices'] + SC_REQUIRED,
                             instance=False, size='small', record_source='G10 report (60 verified); orch-B/smoke/attack.log'),
    'sink-core-witness': dict(root=SC, entry='sink/WitnessCore.dfy', copies=sc_copies, expected_verified=67,
                              add=[(PROPOSAL + '/sink-core/review/WitnessCore.dfy', 'sink/WitnessCore.dfy')],
                              expected_audit=[], expected_code_hits=[], expected_bodiless=[],
                              required=['SinkCoreW.WitnessRun', 'SinkCoreW.WitMinterSound', 'SinkCoreW.StepRefinesCommit',
                                        'SinkCoreW.ZeroAmountRepeats'],
                              instance=True, size='small', record_source='G10 report (67 verified)'),
    'slice-theorem': dict(root=ST, entry='SliceTheorem.dfy', copies=lambda r: st_copies(r) or st_intra(r),
                          expected_verified=1570, expected_audit=[HEX_AXIOM],
                          expected_code_hits=[('library/Std/Strings.dfy', '@Axiom')],
                          expected_bodiless=[('library/Std/Strings.dfy', 'CharsConsistent')],
                          required=['SliceTheorem.SliceSafety', 'SliceTheorem.PerEntry', 'SliceTheorem.ExecInv',
                                    'SliceWitness.Witness', 'SliceWitness.ZeroAmountCommitKeepsStore',
                                    'SliceWitness.WrongArtifactBreaksFlatPath', 'SliceWitness.UncheckedMintBreaksApprovedSpec'],
                          instance=False, size='large',
                          record_source='slice-theorem/records/orchestrator-verify.log (1570 verified)'),
}


def controls_for(name, checkout):
    """Stored negative controls: (id, kind, source, expected_exit, note)."""
    out = []
    if name == 'linked-refund':
        exp = {'N5-decode-reads-response': 0}
        for p in sorted((checkout / PROPOSAL / 'linked-refund/negative').glob('*.diff')):
            out.append((p.stem, 'unified-diff', str(p.relative_to(checkout)), exp.get(p.stem, 4), 'run_check.py CONTROLS'))
        for p in sorted((checkout / PROPOSAL / 'linked-refund/review-controls').glob('M*.diff')):
            out.append((p.stem, 'unified-diff', str(p.relative_to(checkout)), 4, 'D10 report'))
        out.append(('FlatFalse', 'add-entry', PROPOSAL + '/linked-refund/review-controls/FlatFalse.dfy.txt', 4,
                    'D10 report: placed as transport/FlatFalse.dfy (it includes "FlatCore.dfy")'))
    elif name == 'slice-theorem':
        for p in sorted((checkout / PROPOSAL / 'slice-theorem/controls').glob('*.diff')):
            out.append((p.stem, 'unified-diff', str(p.relative_to(checkout)), 4, 'G9 report'))
    elif name == 'sink-core':
        for p in sorted((checkout / PROPOSAL / 'sink-core/mutants').iterdir()):
            if p.is_dir():
                out.append((p.name, 'stored-tree', str(p.relative_to(checkout)), 4, 'run_y7.py MUTANTS; D7 report'))
        mut = checkout / PROPOSAL / 'sink-core/review/mutate.py'
        if mut.exists():
            for zid in z_mutant_names(mut):
                out.append((zid, 'z-mutant', str(mut.relative_to(checkout)), 4, 'G10 report; regenerated from mutate.py M'))
    return out


# ---------------------------------------------------------------- small helpers
def sha_bytes(b):
    return hashlib.sha256(b).hexdigest()


def sha(path):
    return sha_bytes(Path(path).read_bytes())


def src_digest(path):
    """SHA-256 of a file, or the set digest (sorted `path<TAB>sha256` lines) of a folder."""
    path = Path(path)
    if path.is_dir():
        return set_digest((q.relative_to(path).as_posix(), sha(q)) for q in path.rglob('*') if q.is_file())
    return sha(path)


def set_digest(rows):
    return sha_bytes(''.join('%s\t%s\n' % (p, h) for p, h in sorted(rows)).encode())


def numbered(path):
    """A new numbered file name; never overwrite an earlier log."""
    path = Path(path)
    n = 1
    while True:
        cand = path.with_name('%s.%d%s' % (path.stem, n, path.suffix))
        if not cand.exists() and not Path(str(cand) + '.timeout').exists():
            return cand
        n += 1


def strip_comments(text):
    """Remove // and /* */ comments; keep newlines so line numbers stay. Strings are kept (simple scanner)."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == '\\' else 1
            out.append(text[i:j + 1]); i = j + 1
        elif text.startswith('//', i):
            j = text.find('\n', i)
            j = n if j < 0 else j
            i = j
        elif text.startswith('/*', i):
            depth, j = 1, i + 2
            while j < n and depth:
                if text.startswith('/*', j):
                    depth += 1; j += 2
                elif text.startswith('*/', j):
                    depth -= 1; j += 2
                else:
                    j += 1
            out.append('\n' * text.count('\n', i, j)); i = j
        else:
            out.append(c); i += 1
    return ''.join(out)


INCLUDE_RE = re.compile(r'^\s*include\s+"([^"]+)"', re.M)


def include_closure(root, entry):
    """Transitive closure of `include` lines (paths relative to the including file). Fails on a missing file
    or on a path that leaves the root."""
    root = Path(root).resolve()
    seen, todo, missing = {}, [Path(entry)], []
    while todo:
        rel = todo.pop()
        p = (root / rel).resolve()
        try:
            r = p.relative_to(root).as_posix()
        except ValueError:
            missing.append('LEAVES ROOT: %s' % rel); continue
        if r in seen:
            continue
        if not p.is_file():
            missing.append(r); continue
        text = p.read_text(encoding='utf-8', errors='replace')
        seen[r] = sha(p)
        for inc in INCLUDE_RE.findall(strip_comments(text)):
            target = (p.parent / inc).resolve()
            if target.is_relative_to(root):
                todo.append(target.relative_to(root))
            else:
                missing.append('LEAVES ROOT: %s (from %s)' % (inc, r))
    return seen, missing


# ---------------------------------------------------------------- diffs
def apply_unified(diff_text, tree):
    """Apply a unified diff exactly (context must match at the stated line). Returns the list of changed files."""
    files, cur, lines = [], None, diff_text.splitlines(keepends=True)
    i = 0
    changed = []
    while i < len(lines):
        ln = lines[i]
        if ln.startswith('--- '):
            name = ln[4:].split('\t')[0].strip()
            if '/inputs/' in name:
                name = name.split('/inputs/')[-1]
            elif name.startswith('a/'):
                name = name[2:]
            cur = {'path': name, 'hunks': []}
            files.append(cur); i += 2; continue
        if ln.startswith('@@') and cur is not None:
            m = re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', ln)
            start = int(m.group(1)); old, new = [], []
            i += 1
            while i < len(lines) and not lines[i].startswith(('@@', '--- ', 'diff ')):
                t = lines[i]
                if t.startswith('\\'):
                    i += 1; continue
                tag, body = t[:1], t[1:]
                if tag in (' ', ''):
                    old.append(body); new.append(body)
                elif tag == '-':
                    old.append(body)
                elif tag == '+':
                    new.append(body)
                i += 1
            cur['hunks'].append((start, old, new)); continue
        i += 1
    for f in files:
        p = Path(tree) / f['path']
        src = p.read_text(encoding='utf-8').splitlines(keepends=True)
        for start, old, new in sorted(f['hunks'], key=lambda h: -h[0]):
            at = start - 1 if old else start
            if src[at:at + len(old)] != old:
                raise ValueError('hunk at line %d does not match %s' % (start, f['path']))
            src[at:at + len(old)] = new
        p.write_text(''.join(src), encoding='utf-8')
        changed.append(f['path'])
    return changed


def apply_classic(diff_text, target):
    """Apply a classic (normal) diff with no file name to one file. Supports a, d, c commands."""
    src = Path(target).read_text(encoding='utf-8').splitlines(keepends=True)
    cmds, lines, i = [], diff_text.splitlines(keepends=True), 0
    while i < len(lines):
        m = re.match(r'^(\d+)(?:,(\d+))?([adc])(\d+)(?:,(\d+))?\s*$', lines[i])
        if not m:
            raise ValueError('bad classic diff line %r' % lines[i])
        a1 = int(m.group(1)); a2 = int(m.group(2) or a1); op = m.group(3)
        i += 1; old, new = [], []
        while i < len(lines) and lines[i].startswith(('<', '>', '---')):
            if lines[i].startswith('< '):
                old.append(lines[i][2:])
            elif lines[i].startswith('> '):
                new.append(lines[i][2:])
            i += 1
        cmds.append((a1, a2, op, old, new))
    for a1, a2, op, old, new in sorted(cmds, key=lambda c: -c[0]):
        if op == 'a':
            src[a1:a1] = new
        else:
            if src[a1 - 1:a2] != old:
                raise ValueError('classic diff text does not match at %d' % a1)
            src[a1 - 1:a2] = new if op == 'c' else []
    Path(target).write_text(''.join(src), encoding='utf-8')


def z_mutant_names(mutate_py):
    return list(z_mutants(mutate_py, None).keys())


def z_mutants(mutate_py, base_text):
    """Rebuild the Z mutant table of review/mutate.py WITHOUT running its file actions: only the text up to
    `names = sys.argv` is executed, with the sanitised path line and the base assertion removed."""
    text = Path(mutate_py).read_text()
    text = text.split('names = sys.argv')[0]
    text = re.sub(r"^Z = Path\(.*$", "", text, flags=re.M)
    text = re.sub(r"^BASE = .*$", "", text, flags=re.M)
    text = re.sub(r"^src = .*$", "", text, flags=re.M)
    text = re.sub(r"^assert hashlib.*$", "", text, flags=re.M)
    ns = {'src': base_text or ''}
    exec(compile(text, 'mutate.py(table only)', 'exec'), ns)
    return ns['M']


# ---------------------------------------------------------------- the lock script
class Runner:
    def __init__(self, args):
        self.args = args
        self.lock = Path(args.lock).resolve()
        self.z3 = Path(args.z3).resolve()
        self.dafny = Path(args.dafny).resolve()
        self.out = Path(args.out).resolve()
        self.dafny_versions = set()

    def dafny_run(self, workdir, log, dafny_args, size):
        """Run one Dafny command through the lock script, with the retry policy of WORKER_RULES.md.
        Returns dict(exit, log, attempts, tier, not_run_reason)."""
        attempts, tiers = [], [self.args.timeout]
        if self.args.heavy_timeout:
            tiers.append(self.args.heavy_timeout)
        for tmo in tiers:
            refused = 0
            while True:
                lg = numbered(log)
                cmd = [str(self.lock), OWNER, str(workdir), str(lg), str(tmo)] + dafny_args
                t0 = time.time()
                code = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
                attempts.append({'log': self.rel_out(lg), 'timeout_s': tmo, 'exit': code, 'wall_s': round(time.time() - t0, 1)})
                v = re.search(r'^# dafny: (.*)$', lg.read_text(errors='replace'), re.M) if lg.exists() else None
                if v:
                    self.dafny_versions.add(v.group(1).strip())
                if code in (75, 76):
                    refused += 1
                    if refused >= self.args.max_retries:
                        return {'exit': None, 'attempts': attempts, 'not_run_reason': 'refused %d times (exit %d)' % (refused, code)}
                    time.sleep(self.args.retry_wait); continue
                break
            if code == 124:
                continue  # next tier
            return {'exit': code, 'log': lg, 'attempts': attempts}
        return {'exit': None, 'attempts': attempts, 'not_run_reason': 'timeout (124) at every tier'}

    def rel_out(self, p):
        return os.path.relpath(Path(p).resolve(), self.out)


SUMMARY_RE = re.compile(r'Dafny program verifier finished with (\d+) verified, (\d+) errors?(?:, (\d+) out of resource)?(?:, (\d+) time outs?)?')


def parse_log(text):
    m = None
    for m in SUMMARY_RE.finditer(text):
        pass
    errors = [l.strip() for l in text.splitlines() if ': Error' in l]
    oor = [l for l in errors if 'out of resource' in l.lower() or 'resource' in l.lower() and 'out' in l.lower()]
    tm = re.search(r'^\s*([\d.]+) real', text, re.M)
    rss = re.search(r'^\s*(\d+)\s+maximum resident set size', text, re.M)
    return {'summary': m.group(0) if m else None,
            'verified': int(m.group(1)) if m else None, 'errors': int(m.group(2)) if m else None,
            'out_of_resource': int(m.group(3) or 0) if m else None, 'time_outs': int(m.group(4) or 0) if m else None,
            'error_lines': errors[:12], 'error_lines_total': len(errors), 'oor_error_lines': len(oor),
            'real_s': float(tm.group(1)) if tm else None, 'max_rss_bytes': int(rss.group(1)) if rss else None}


def read_csv(path):
    if not Path(path).exists():
        return None
    with open(path, newline='') as f:
        return [(r.get('TestResult.DisplayName', ''), r.get('TestResult.Outcome', '')) for r in csv.DictReader(f)]


def required_check(rows, required):
    res, ok = [], True
    for name in required:
        hit = [(d, o) for d, o in (rows or []) if d == name or d.startswith(name + ' (')]
        good = bool(hit) and all(o == 'Passed' for _, o in hit)
        ok = ok and good
        res.append({'name': name, 'csv_rows': len(hit), 'all_passed': all(o == 'Passed' for _, o in hit) if hit else False,
                    'present': bool(hit)})
    return ok, res


GREP = [('assume', re.compile(r'\bassume\b')), ('{:axiom}', re.compile(r'\{:\s*axiom\b')), ('@Axiom', re.compile(r'@Axiom\b')),
        ('{:verify false}', re.compile(r'\{:\s*verify\s+false\s*\}')), ('@Verify(false)', re.compile(r'@Verify\s*\(\s*false')),
        ('expect', re.compile(r'\bexpect\b')), ('{:extern}', re.compile(r'\{:\s*extern\b')), ('@Extern', re.compile(r'@Extern\b'))]
DECL_START = re.compile(r'^\s*(?:@\w+.*|(?:ghost|static|opaque|twostate|least|greatest|abstract)\s+)*(lemma|method|function|predicate|module|datatype|codatatype|type|const|class|trait|import|iterator|newtype|include)\b')
LEMMA_RE = re.compile(r'^\s*(?:(?:ghost|static|twostate|least|greatest)\s+)*lemma\s+(?:\{[^}]*\}\s*)*([A-Za-z_][\w\']*)')


def grep_and_bodiless(tree, files):
    hits, bodiless = [], []
    for rel in files:
        raw = (Path(tree) / rel).read_text(encoding='utf-8', errors='replace')
        code = strip_comments(raw)
        raw_lines, code_lines = raw.splitlines(), code.splitlines()
        for no, line in enumerate(raw_lines, 1):
            cl = code_lines[no - 1] if no - 1 < len(code_lines) else ''
            for label, rx in GREP:
                if rx.search(line):
                    hits.append({'file': rel, 'line': no, 'pattern': label, 'in_code': bool(rx.search(cl)), 'text': line.strip()[:160]})
        # bodiless lemma heuristic (dafny audit is the authority): after a lemma header, the first line that
        # starts with '{' (or a header line ending in '{' / '{}') is a body; a new declaration or '}' first means no body.
        for idx, line in enumerate(code_lines):
            m = LEMMA_RE.match(line)
            if not m:
                continue
            body = None
            for j in range(idx, len(code_lines)):
                s = code_lines[j].strip()
                if j > idx and not s:
                    continue
                if j > idx and s.startswith('{') and not s.startswith('{:'):
                    body = True; break
                if s.endswith('{') or (s.endswith('{}') and not re.search(r'(==|!=|\+|-|\*|:=|<=|>=|<|>|\(|,|\bin)\s*\{\}$', s)):
                    body = True; break
                if j > idx and (DECL_START.match(code_lines[j]) or s.startswith(('}', '@'))):
                    body = False; break
            if body is False:
                bodiless.append({'file': rel, 'line': idx + 1, 'lemma': m.group(1)})
    return hits, bodiless


def parse_audit(report):
    if not Path(report).exists():
        return None
    rows = []
    for line in Path(report).read_text().splitlines():
        if line.startswith('|') and not line.startswith(('|Name', '|----')):
            rows.append(line.split('|')[1].strip())
    return sorted(rows)


# ---------------------------------------------------------------- one proof
def stage_tree(checkout, spec, work, mutate=None):
    """Copy the proof folder into a fresh work tree; add files; derive files; then optionally mutate."""
    if work.exists():
        shutil.rmtree(work)
    shutil.copytree(checkout / spec['root'], work)
    derived = []
    for src, dst in spec.get('add', []):
        shutil.copyfile(checkout / src, work / dst)
        derived.append({'path': dst, 'how': 'copied from %s' % src, 'source_sha256': sha(checkout / src)})
    for kind, diff, target in spec.get('derive', []):
        before = sha(work / target)
        apply_classic((checkout / diff).read_text(), work / target)
        derived.append({'path': target, 'how': 'classic diff %s applied to the checkout file' % diff,
                        'diff_sha256': sha(checkout / diff), 'base_sha256': before, 'result_sha256': sha(work / target)})
    if mutate:
        before = {p.relative_to(work).as_posix(): sha(p) for p in work.rglob('*') if p.is_file()}
        mutate(work)
        for p in sorted(work.rglob('*')):
            r = p.relative_to(work).as_posix()
            if p.is_file() and before.get(r) != sha(p):
                derived.append({'path': r, 'how': 'changed by the self-control', 'result_sha256': sha(p)})
    return derived


def run_proof(R, checkout, name, spec, rec_dir, verify=True, mutate=None, label=None, do_build=False):
    label = label or name
    rec_dir.mkdir(parents=True, exist_ok=True)
    work = R.out / 'work' / label
    derived = stage_tree(checkout, spec, work, mutate)
    derived_paths = {d['path'] for d in derived}
    closure, missing = include_closure(work, spec['entry'])
    folder_files = sorted(p.relative_to(work).as_posix() for p in work.rglob('*') if p.is_file())
    rec = {'proof': name, 'label': label, 'root_in_checkout': spec['root'], 'entry': spec['entry'],
           'record_source_of_expected_values': spec.get('record_source'), 'derived_or_added_files': derived,
           'closure': [{'path': p, 'sha256': h,
                        'checkout_sha256': (sha(checkout / spec['root'] / p) if (checkout / spec['root'] / p).is_file() else None),
                        'same_as_checkout': (p not in derived_paths and (checkout / spec['root'] / p).is_file()
                                             and sha(checkout / spec['root'] / p) == h)}
                       for p, h in sorted(closure.items())],
           'closure_count': len(closure), 'closure_missing': missing, 'closure_digest': set_digest(closure.items()),
           'folder_files_not_in_closure': [f for f in folder_files if f not in closure],
           'fail_reasons': []}
    fails = rec['fail_reasons']
    if missing:
        fails.append('CLOSURE_MISSING')
    for c in rec['closure']:
        if c['path'] not in derived_paths and not c['same_as_checkout']:
            fails.append('IDENTITY: work file %s differs from the checkout' % c['path'])
    # copies
    copies = []
    for p, h in sorted(closure.items()):
        m = spec['copies'](p)
        st = STATED.get(p)
        row = {'copy': p, 'copy_sha256': h}
        if m:
            kind, orig = m
            o = checkout / orig
            row.update({'original': orig, 'original_kind': kind,
                        'original_sha256': sha(o) if o.is_file() else None, 'equal': o.is_file() and sha(o) == h})
            if not row['equal']:
                fails.append('IDENTITY: copy %s != original %s' % (p, orig))
        elif p.startswith('library/Std/'):
            row.update({'original': 'Dafny standard library v4.11.0, Source/DafnyStandardLibraries/src/Std/' + p[len('library/Std/'):],
                        'original_kind': 'NO ORIGINAL IN CHECKOUT (upstream only)', 'equal': None})
        elif p in derived_paths:
            row.update({'original': None, 'original_kind': 'derived/added in this run', 'equal': None})
        else:
            row.update({'original': None, 'original_kind': 'NO ORIGINAL IN CHECKOUT', 'equal': None})
        if st:
            row.update({'stated_sha256': st[0], 'stated_in': st[1], 'equals_stated': st[0] == h})
            if p not in derived_paths and st[0] != h:
                fails.append('IDENTITY: %s != stated digest (%s)' % (p, st[1]))
        copies.append(row)
    rec['copies'] = copies
    identity_ok = not fails
    rec['identity_ok'] = identity_ok
    files = sorted(closure)
    (rec_dir / ('closure-%s.txt' % label)).write_text(''.join('%s  %s\n' % (closure[p], p) for p in files))
    # grep / bodiless (no Dafny)
    hits, bodiless = grep_and_bodiless(work, files)
    rec['grep_hits'] = hits
    rec['bodiless_lemmas_heuristic'] = bodiless
    code_hits = sorted({(h['file'], h['pattern']) for h in hits if h['in_code']})
    rec['grep_code_hits_unexpected'] = [list(x) for x in code_hits if x not in set(map(tuple, spec['expected_code_hits']))]
    rec['grep_code_hits_missing'] = [list(x) for x in spec['expected_code_hits'] if tuple(x) not in code_hits]
    if rec['grep_code_hits_unexpected'] or rec['grep_code_hits_missing']:
        fails.append('GREP: code hits differ from expected')
    bl = sorted({(b['file'], b['lemma']) for b in bodiless})
    rec['bodiless_unexpected'] = [list(x) for x in bl if x not in set(map(tuple, spec['expected_bodiless']))]
    if rec['bodiless_unexpected']:
        fails.append('BODILESS: unexpected bodiless lemma (heuristic)')
    if not verify or not identity_ok:
        rec['verify'] = {'state': 'NOT RUN', 'why': 'identity failed (fail-closed)' if not identity_ok else 'not requested'}
        rec['establishes'] = ESTABLISH_IDENTITY
        rec['status'] = 'FAIL' if fails else 'IDENTITY-ONLY'
        return rec
    # verify
    csvp = numbered(rec_dir / ('verify-%s.csv' % label))
    dargs = ['verify', '--solver-path', str(R.z3)] + GATE_OPTIONS + [
        '--log-format', 'csv;LogFileName=%s' % os.path.relpath(csvp, work), spec['entry']]
    r = R.dafny_run(work, rec_dir / ('verify-%s.log' % label), dargs, spec.get('size'))
    v = {'argv': ['dafny'] + [a if a != str(R.z3) else '{z3}' for a in dargs[:-3]] + ['--log-format', 'csv;LogFileName={csv}', spec['entry']],
         'cwd': 'work copy of ' + spec['root'], 'attempts': r['attempts'], 'exit': r['exit']}
    if r['exit'] is None:
        v['state'] = 'NOT RUN'; v['why'] = r['not_run_reason']
        rec['verify'] = v; rec['establishes'] = ESTABLISH_IDENTITY
        fails.append('VERIFY NOT RUN'); rec['status'] = 'NOT RUN'
        return rec
    text = r['log'].read_text(errors='replace')
    v.update(parse_log(text))
    v['log'] = R.rel_out(r['log']); v['log_sha256'] = sha(r['log'])
    rows = read_csv(csvp)
    v['csv'] = R.rel_out(csvp) if csvp.exists() else None
    v['csv_sha256'] = sha(csvp) if csvp.exists() else None
    v['csv_rows'] = len(rows) if rows is not None else None
    v['csv_not_passed'] = [d for d, o in (rows or []) if o != 'Passed']
    v['state'] = 'RAN'
    rec['verify'] = v
    rec['establishes'] = ESTABLISH_RERUN
    if r['exit'] != 0:
        fails.append('VERIFY: exit %s' % r['exit'])
    if not v['verified'] or v['errors'] != 0:
        fails.append('VERIFY: summary %r (zero obligations or errors)' % v['summary'])
    if rows is None or v['csv_rows'] != v['verified'] or v['csv_not_passed']:
        fails.append('CSV: rows %s vs verified %s; not passed %d' % (v['csv_rows'], v['verified'], len(v['csv_not_passed'])))
    ok, req = required_check(rows, spec['required'])
    rec['required_lemmas'] = req
    rec['required_lemmas_ok'] = ok
    if not ok:
        fails.append('REQUIRED_LEMMA: missing or not passed: %s' % [x['name'] for x in req if not (x['present'] and x['all_passed'])])
    rec['count_equals_stored_record'] = v['verified'] == spec['expected_verified']
    rec['stored_record_count'] = spec['expected_verified']
    # audit
    rep = numbered(rec_dir / ('audit-%s.md' % label))
    a = R.dafny_run(work, rec_dir / ('audit-%s.log' % label),
                    ['audit'] + files + ['--report-format', 'md', '--report-file', os.path.relpath(rep, work)], 'small')
    found = parse_audit(rep)
    rec['audit'] = {'exit': a['exit'], 'attempts': a['attempts'], 'report': R.rel_out(rep) if rep.exists() else None,
                    'report_sha256': sha(rep) if rep.exists() else None, 'files_audited': len(files),
                    'findings': found, 'expected_findings': spec['expected_audit']}
    if a['exit'] is None:
        fails.append('AUDIT NOT RUN')
    elif a['exit'] != 0 or found is None or found != sorted(spec['expected_audit']):
        fails.append('AUDIT: exit %s findings %s expected %s' % (a['exit'], found, spec['expected_audit']))
    if do_build and spec.get('instance'):
        rec['build'] = run_build(R, work, spec, rec_dir, label, rows)
    if fails:
        rec['status'] = 'FAIL'
    elif not rec['count_equals_stored_record']:
        rec['status'] = 'VERIFIED-COUNT-DIFFERS-FROM-RECORD'
    else:
        rec['status'] = 'PASS'
    return rec


def run_build(R, work, spec, rec_dir, label, verify_rows):
    """`dafny build` re-checks inherited lemmas of a refinement instance (pinned 4.11.0). Output goes to records."""
    csvp = numbered(rec_dir / ('translate-%s.csv' % label))
    outdir = rec_dir / ('translate-%s-output' % label)
    outdir.mkdir(exist_ok=True)
    # `dafny build` = verify + translate + compile. Compile needs the `dotnet` program (absent here: exit 3 after
    # verification). `dafny translate cs` runs the same verification as build, without the compile step.
    dargs = ['translate', 'cs', '--solver-path', str(R.z3)] + GATE_OPTIONS + [
        '--log-format', 'csv;LogFileName=%s' % os.path.relpath(csvp, work),
        '--output', os.path.relpath(outdir / 'program', work), spec['entry']]
    r = R.dafny_run(work, rec_dir / ('translate-%s.log' % label), dargs, spec.get('size'))
    b = {'argv': ['dafny', 'translate', 'cs', '--solver-path', '{z3}'] + GATE_OPTIONS +
         ['--log-format', 'csv;LogFileName={csv}', '--output', '{records}/translate-%s-output/program' % label, spec['entry']],
         'exit': r['exit'], 'attempts': r['attempts']}
    if r['exit'] is None:
        b['state'] = 'NOT RUN'; b['why'] = r['not_run_reason']; return b
    b.update(parse_log(r['log'].read_text(errors='replace')))
    b['log'] = R.rel_out(r['log'])
    rows = read_csv(csvp)
    b['csv'] = R.rel_out(csvp) if csvp.exists() else None
    b['csv_rows'] = len(rows) if rows is not None else None
    vset = {d for d, _ in (verify_rows or [])}
    b['rows_only_in_build'] = sorted(d for d, _ in (rows or []) if d not in vset)
    b['rows_only_in_build_not_passed'] = sorted(d for d, o in (rows or []) if d not in vset and o != 'Passed')
    b['state'] = 'RAN'
    return b


# ---------------------------------------------------------------- controls
def run_control(R, checkout, name, spec, ctl, rec_dir):
    cid, kind, source, expected, note = ctl
    cdir = rec_dir / 'controls'
    cdir.mkdir(parents=True, exist_ok=True)
    work = R.out / 'work' / ('%s--%s' % (name, cid))
    entry = spec['entry']
    row = {'control': cid, 'kind': kind, 'source': source, 'source_sha256': src_digest(checkout / source),
           'expected_exit': expected, 'expected_source': note}
    try:
        if kind == 'stored-tree':
            if work.exists():
                shutil.rmtree(work)
            shutil.copytree(checkout / source, work)
            same = {p.relative_to(work).as_posix(): sha(p) == sha(checkout / spec['root'] / p.relative_to(work))
                    for p in work.rglob('*.dfy') if (checkout / spec['root'] / p.relative_to(work)).is_file()}
            row['files_equal_to_base'] = same
            row['changed_files'] = sorted(k for k, v in same.items() if not v)
        else:
            stage_tree(checkout, spec, work)
            if kind == 'unified-diff':
                row['changed_files'] = apply_unified((checkout / source).read_text(), work)
            elif kind == 'add-entry':
                shutil.copyfile(checkout / source, work / 'transport/FlatFalse.dfy')
                entry = 'transport/FlatFalse.dfy'; row['changed_files'] = ['transport/FlatFalse.dfy (added)']
            elif kind == 'z-mutant':
                base = (work / 'sink/SinkCore.dfy').read_text()
                table = z_mutants(checkout / source, base)
                s = base
                for old, new in table[cid]:
                    assert s.count(old) == 1, (cid, old[:40])
                    s = s.replace(old, new)
                (work / 'sink/SinkCore.dfy').write_text(s)
                row['changed_files'] = ['sink/SinkCore.dfy']
        row['entry'] = entry
        row['mutated_sha256'] = {f: sha(work / f) for f in row.get('changed_files', []) if (work / f).is_file()}
    except Exception as e:  # a control that cannot be built is reported, not skipped
        row.update({'state': 'NOT BUILT', 'why': repr(e), 'exit': None, 'class': 'NOT RUN'})
        return row
    csvp = numbered(cdir / ('%s.csv' % cid))
    dargs = ['verify', '--solver-path', str(R.z3)] + GATE_OPTIONS + [
        '--log-format', 'csv;LogFileName=%s' % os.path.relpath(csvp, work), entry]
    r = R.dafny_run(work, cdir / ('%s.log' % cid), dargs, spec.get('size'))
    row['attempts'] = r['attempts']; row['exit'] = r['exit']
    if r['exit'] is None:
        row.update({'state': 'NOT RUN', 'why': r['not_run_reason'], 'class': 'NOT RUN'})
        return row
    p = parse_log(r['log'].read_text(errors='replace'))
    row.update(p); row['log'] = R.rel_out(r['log']); row['state'] = 'RAN'
    rows = read_csv(csvp) or []
    row['csv_failed_rows'] = [d + ': ' + o for d, o in rows if o != 'Passed'][:20]
    if r['exit'] == 0:
        row['class'] = 'PASSES (verifier accepts)'
    elif r['exit'] == 4 and (p['errors'] or 0) > 0:
        row['class'] = 'REFUTED (real error)'
    elif r['exit'] == 4 and (p['out_of_resource'] or 0) > 0:
        row['class'] = 'OUT-OF-RESOURCE ONLY (not a refutation)'
    else:
        row['class'] = 'OTHER (exit %s)' % r['exit']
    row['as_expected'] = r['exit'] == expected
    shutil.rmtree(work, ignore_errors=True)
    return row


# ---------------------------------------------------------------- self-controls
def remove_lemma(text, name):
    i = text.index('lemma ' + name)
    i = text.rfind('\n', 0, i) + 1
    j = text.index('\n  {', i) + 3
    depth, k = 0, j
    while True:
        if text[k] == '{':
            depth += 1
        elif text[k] == '}':
            depth -= 1
            if depth == 0:
                break
        k += 1
    return text[:i] + text[k + 1:]


def self_controls(R, checkout):
    spec = PROOFS['sink-core']
    rec_dir = R.out / 'records' / 'self-controls'
    out = []

    def flip(work):
        p = work / 'impl/Refund.dfy'
        b = bytearray(p.read_bytes()); b[-2] = b[-2] ^ 0x01; p.write_bytes(bytes(b))

    def drop(work):
        p = work / 'sink/SinkCore.dfy'; p.write_text(remove_lemma(p.read_text(), 'ZeroAmountRepeats'))

    def assume(work):
        p = work / 'sink/SinkCore.dfy'; t = p.read_text(); k = t.rstrip().rfind('}')
        p.write_text(t[:k] + '  lemma SelfControlAssumeFalse()\n    ensures false\n  {\n    assume false;\n  }\n' + t[k:])

    def empty(work):
        (work / 'sink/SinkCore.dfy').write_text('')

    cases = [('a-one-byte-in-copy', flip, 'IDENTITY'), ('b-headline-lemma-removed', drop, 'REQUIRED_LEMMA'),
             ('c-assume-false', assume, 'GREP'), ('d-empty-main-file', empty, 'REQUIRED_LEMMA')]
    for cid, fn, want in cases:
        rec = run_proof(R, checkout, 'sink-core', spec, rec_dir, verify=True, mutate=fn, label='self-' + cid)
        reasons = rec['fail_reasons']
        ok = rec['status'] != 'PASS' and any(x.startswith(want) for x in reasons)
        if cid.startswith('c'):
            ok = ok and any(x.startswith('AUDIT') for x in reasons) if rec.get('audit', {}).get('exit') is not None else ok
        out.append({'self_control': cid, 'expected': 'record must NOT pass; reason %s' % want, 'status': rec['status'],
                    'fail_reasons': reasons, 'as_expected': ok,
                    'audit_findings': rec.get('audit', {}).get('findings'),
                    'verify_summary': rec.get('verify', {}).get('summary'), 'verify_exit': rec.get('verify', {}).get('exit')})
        shutil.rmtree(R.out / 'work' / ('self-' + cid), ignore_errors=True)
    return out


# ---------------------------------------------------------------- environment
def environment(R, checkout):
    def run(cmd):
        try:
            return subprocess.run(cmd, capture_output=True, text=True, timeout=30).stdout.strip()
        except Exception as e:
            return 'ERROR %r' % e
    lock_text = R.lock.read_text()
    m = re.search(r'^DAFNY=(.*)$', lock_text, re.M)
    commit_file = checkout.parent / 'checkout.COMMIT'
    return {'date_utc': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
            'commit': (commit_file.read_text().strip() if commit_file.exists() else R.args.commit),
            'checkout_kind': 'git archive of the commit (no .git; no working-tree changes)',
            'os': platform.platform(), 'machine': platform.machine(), 'uname_without_host': ' '.join([platform.uname().system, platform.uname().release, platform.uname().version, platform.uname().machine]),
            'python': platform.python_version(),
            'dafny_launcher_sha256': sha(R.dafny), 'dafny_dll_sha256': sha(R.dafny.parent / 'Dafny.dll') if (R.dafny.parent / 'Dafny.dll').exists() else None,
            'dafny_version_from_lock_logs': sorted(R.dafny_versions),
            'z3_sha256': sha(R.z3), 'z3_version': run([str(R.z3), '-version']),
            'lock_script_sha256': sha(R.lock), 'lock_script_dafny_line': m.group(1) if m else None,
            'lock_script_runs_same_dafny_as_argument': bool(m) and Path(m.group(1).replace('$ROOT', re.search(r'^ROOT=(.*)$', lock_text, re.M).group(1))).resolve() == R.dafny,
            'gate_options': ['--solver-path', '{z3}'] + GATE_OPTIONS,
            'gate_options_equal_gate_backends_dafny_py': gate_options_equal(checkout)}


def gate_options_equal(checkout):
    t = (checkout / 'gate/backends/dafny.py').read_text()
    m = re.search(r'OPTIONS = \[(.*?)\]', t, re.S)
    if not m:
        return None
    items = re.findall(r"'([^']*)'", m.group(1))
    return items[:1] == ['--solver-path'] and items[2:] == GATE_OPTIONS


def upstream_std(checkout, tag):
    """Optional network check of the Std copies against the upstream Dafny tag (a tag can move: weak pin)."""
    res = []
    for p in sorted((checkout / LR / 'library/Std').rglob('*.dfy')):
        rel = p.relative_to(checkout / LR / 'library/Std').as_posix()
        url = 'https://raw.githubusercontent.com/dafny-lang/dafny/%s/Source/DafnyStandardLibraries/src/Std/%s' % (tag, rel)
        try:
            data = urllib.request.urlopen(url, timeout=20).read()
            res.append({'copy': 'library/Std/' + rel, 'upstream': url, 'upstream_sha256': sha_bytes(data),
                        'copy_sha256': sha(p), 'equal': sha_bytes(data) == sha(p)})
        except Exception as e:
            res.append({'copy': 'library/Std/' + rel, 'upstream': url, 'error': repr(e), 'equal': None})
    return res


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--checkout', default=str(HERE / 'checkout'))
    ap.add_argument('--commit', default=None, help='recorded only when checkout.COMMIT is absent')
    ap.add_argument('--out', default=str(HERE))
    ap.add_argument('--dafny', default=os.environ.get('DAFNY'))
    ap.add_argument('--z3', default=os.environ.get('Z3'))
    ap.add_argument('--lock', default=os.environ.get('DAFNY_LOCK'))
    ap.add_argument('--proofs', nargs='*', default=[], help='names from PROOFS; empty = none')
    ap.add_argument('--identity-only', action='store_true', help='closure, copies and grep only; no Dafny')
    ap.add_argument('--build', action='store_true', help='also dafny build for refinement instances')
    ap.add_argument('--controls', nargs='*', default=[], help='proof names whose stored controls to run')
    ap.add_argument('--only-controls', nargs='*', default=[], help='restrict to these control ids')
    ap.add_argument('--self-controls', action='store_true')
    ap.add_argument('--upstream-std', default=None, help='tag, for example v4.11.0 (network)')
    ap.add_argument('--timeout', type=int, default=90)
    ap.add_argument('--heavy-timeout', type=int, default=600, help='0 = no heavy tier')
    ap.add_argument('--max-retries', type=int, default=5)
    ap.add_argument('--retry-wait', type=int, default=180)
    args = ap.parse_args()
    for k in ('dafny', 'z3', 'lock'):
        if not getattr(args, k):
            ap.error('--%s (or its environment variable) is required' % k)
    R = Runner(args)
    checkout = Path(args.checkout).resolve()
    R.out.mkdir(parents=True, exist_ok=True)
    recp = R.out / 'PROOF_RECORDS.json'
    db = json.loads(recp.read_text()) if recp.exists() else {'proofs': {}, 'controls': {}, 'invocations': []}
    db['schema'] = 'forge.nightshift.f-records/1'
    db['what_the_record_establishes'] = (
        'Per proof, "establishes" says "%s" when the pinned Dafny ran tonight on the checkout bytes listed in '
        '"closure" (exit code, summary, CSV and audit are stored), and "%s" when only digests were compared. '
        'No entry says that a theorem means what its report says; the statements are model-level Dafny facts '
        'and the reference values were computed by the same agent family on the same machine.'
        % (ESTABLISH_RERUN, ESTABLISH_IDENTITY))
    db['checkout'] = os.path.relpath(checkout, R.out)
    inv = {'argv': [a if not a.startswith('/') else '{abs}' for a in sys.argv[1:]],
           'start_utc': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}
    for name in args.proofs:
        spec = PROOFS[name]
        print('== proof', name, flush=True)
        rec = run_proof(R, checkout, name, spec, R.out / 'records' / name, verify=not args.identity_only, do_build=args.build)
        db['proofs'][name] = rec
        print('   status', rec['status'], rec['fail_reasons'][:4], rec.get('verify', {}).get('summary'), flush=True)
        recp.write_text(json.dumps(db, indent=1) + '\n')
    for name in args.controls:
        spec = PROOFS[name]
        rows = db['controls'].get(name, [])
        for ctl in controls_for(name, checkout):
            if args.only_controls and ctl[0] not in args.only_controls:
                continue
            print('== control', name, ctl[0], flush=True)
            row = run_control(R, checkout, name, spec, ctl, R.out / 'records' / name)
            rows = [x for x in rows if x['control'] != ctl[0]] + [row]
            db['controls'][name] = rows
            print('   exit', row.get('exit'), row.get('class'), row.get('summary'), flush=True)
            recp.write_text(json.dumps(db, indent=1) + '\n')
    if args.self_controls:
        db['self_controls'] = self_controls(R, checkout)
        for s in db['self_controls']:
            print('== self-control', s['self_control'], 'as_expected', s['as_expected'], s['fail_reasons'][:3], flush=True)
    if args.upstream_std:
        db['std_upstream_check'] = {'tag': args.upstream_std, 'note': 'network; a tag is a weak pin', 'files': upstream_std(checkout, args.upstream_std)}
    db['environment'] = environment(R, checkout)
    inv['end_utc'] = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    db['invocations'].append(inv)
    recp.write_text(json.dumps(db, indent=1) + '\n')
    bad = [n for n in args.proofs if db['proofs'][n]['status'] not in ('PASS', 'IDENTITY-ONLY')]
    print('RESULT: %s; this records verifier runs and digests; it does not establish theorem meaning'
          % ('all requested proofs PASS' if not bad else 'NOT PASS: %s' % bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())

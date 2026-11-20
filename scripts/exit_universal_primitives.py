#!/usr/bin/env python3
"""V1.1 universal primitives pack (primitives 6 to 9): EXIT checks of src/primitives_v2, its tests, the policy
compiler (src/primitives_v2/py/policy_to_dfy.py), the Dafny sources and the self-repair demo.

What a pass means: on this machine the finite checks below gave the recorded results. The engine is unproved Rust:
NATIVE CHECK. The suites, the demo and the changed copies are FINITE TESTS. The only Dafny statements are about Dafny
sources (FarkasCert.dfy and the four generated MODELS), not about the Rust engine. end_to_end stays false. The bundle
is a RECORD, NOT gate evidence. This script starts tools and compares results; it decides nothing for a store.

Cases (python3 scripts/exit_universal_primitives.py --case NAME):
  build      source rules (line 1 of main.rs is #![forbid(unsafe_code)]; no `unsafe` in code; no extern crate; every
             `use` from std, core, alloc, crate, self, super or an item of the same file; no Cargo file; the Python
             files import only the standard library and the named repository modules), the production and the
             test-seams build, each built twice and byte-compared, the Goal 20 airlock engine (read-only source; the
             money vectors replay through it), a control copy with one `unsafe` block that must not compile, and the
             ADDITIVE check: against the merge-base with `main`, no tracked file is modified or deleted (only ROADMAP.md
             and unsure.md may be), and no changed or added path lies under a protected path.
  suite      every suite of tests/primitives_v2/ (test_engine, test_ledger_graph, test_taint, test_farkas,
             test_policy_to_dfy with all cases, test_sdk_primitives, test_demo), all cases, real exit codes; the case
             names must be the suite's own list. Dafny: the Python build of FarkasCert.dfy (for test_farkas) and the
             verify, audit and vectors runs inside test_policy_to_dfy.
  proofs     `dafny verify` + `dafny audit` (compared with the empty baseline gate/expected-audit.md) on
             src/primitives_v2/dafny/FarkasCert.dfy and the four committed generated models; generator determinism
             (`gen` in 16 processes with PYTHONHASHSEED 0..15, byte-compared with the committed .dfy; `vectors`
             recomputed and compared with the committed vector files, whole file, byte for byte); spec clearing of each model through
             `policy_to_dfy.py clear` (scripts/spec_clearing.py of the main checkout, imported, as the primitive 9
             worker ran it; nothing is written under clearing/: checked before and after).
  demo       examples/universal_self_repair/run_demo.py twice (exit 0; the results files equal outside the key
             `measured`) and its --self-test (exit 0).
  mutations  every changed copy of tests/primitives_v2/mutants.py, mutants_p7.py, mutants_p8.py, mutants_p9.py and
             mutants_sdk.py (changed copies of the SDK, killed by test_sdk_primitives.py): each
             must be KILLED for its named reason (the scripts check the reason text); each script's unchanged control
             must pass. A copy that nothing kills is NOT KILLED and the case FAILS unless it is in ACCEPTED_SURVIVORS
             with a written reason (that list is EMPTY; only the owner or the orchestrator may add to it).
  evidence   build, suite, proofs, demo and mutations twice into build/universal_primitives/evidence/attempt-NNNN/
             run-1 and run-2; evidence.json holds only deterministic content (hashes, counts, verdicts); every time
             goes to measurements.json. The two bundles must be byte-identical; the sha256 is printed.
Raw outputs: build/universal_primitives/<case>/attempt-NNNN/ (ignored by git).
Dafny: one Dafny process at a time on this machine. Before each Dafny step this script waits (poll 30 s, at most
60 min) while a process matches 'dafny/dafny|Holmake|/hol |z3-4.12.1'; the suites and the generator wait the same way
for 'dafny/dafny'. A step that cannot get the slot is NOT RUN, and the case FAILS.
Exit: 0 every check of the case is true; 1 a check failed; 2 a case could not run (NOT RUN). Timings are indicative.
"""

import argparse
import ast
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build/universal_primitives'
RUSTC = '/Users/mackianni/.cargo/bin/rustc'
RUSTC_FLAGS = ['--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3']   # PROTOCOL.md section 1
RUSTC_VERSION = 'rustc 1.92.0 (ded5c06cf 2025-12-08)'
DAFNY = '/Users/mackianni/forge/.toolchain/dafny-4.11.0/dafny/dafny'
DAFNY_ROOT = Path('/Users/mackianni/forge')     # the checkout that holds the pinned toolchain (cwd of every Dafny run)
DAFNY_OPTIONS = ['--solver-path', '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1', '--resource-limit', '1000000',
                 '--verification-time-limit', '0', '--cores', '1', '--verify-included-files', '--track-print-effects']
BASELINE = ROOT / 'gate/expected-audit.md'      # read only: the empty audit baseline
SLOT = 'dafny/dafny|Holmake|/hol |z3-4.12.1'
PY = sys.executable

ENGINE_SRC = 'src/primitives_v2'
AIRLOCK_SRC = 'src/airlock'
FARKAS_DFY = 'src/primitives_v2/dafny/FarkasCert.dfy'
GENERATOR = 'src/primitives_v2/py/policy_to_dfy.py'
POLICIES = ['money-refunds', 'rate-api', 'rate-burst', 'transfer-cash']
MODELS = {'money-refunds': 'money-refunds-p9', 'rate-api': 'rate_window-api-p9', 'rate-burst': 'rate_window-burst-p9',
          'transfer-cash': 'transfer-cash-p9'}
DEMO = 'examples/universal_self_repair/run_demo.py'
SUITES = ['test_engine', 'test_ledger_graph', 'test_taint', 'test_farkas', 'test_policy_to_dfy', 'test_sdk_primitives', 'test_demo']
MUTANT_SCRIPTS = ['mutants', 'mutants_p7', 'mutants_p8', 'mutants_p9', 'mutants_sdk']
PYTHON_FILES = [GENERATOR, DEMO, 'sdk/py/forge_primitives.py', 'scripts/exit_universal_primitives.py'] + \
    ['tests/primitives_v2/%s.py' % n for n in SUITES + MUTANT_SCRIPTS]
REPO_MODULES = {  # non-stdlib imports that the Python files may make, and why
    'policy_model': 'src/airlock/py/policy_model.py (Goal 20 strict money loader; read-only reuse)',
    'forge_primitives': 'sdk/py/forge_primitives.py (this pack)',
    'spec_clearing': 'scripts/spec_clearing.py of the main checkout (imported unchanged by policy_to_dfy.py clear)',
    '_dafny': 'the Dafny Python runtime from a pinned-Dafny build output (Dafny\'s own output)',
    'FarkasCert': 'FarkasCert.dfy compiled by the pinned Dafny Python back end (Dafny\'s own output)',
}
PROTECTED_DIRS = ('gate/', 'spec/', 'policy/', 'clearing/')
PROTECTED_FILES = ('spec.lock', 'package.json', 'package-lock.json', 'tsconfig.json')
ALLOWED_MODIFIED = ('ROADMAP.md', 'unsure.md')

# Changed copies that nothing kills and that the owner or the orchestrator ACCEPTED, with the written reason.
# name -> reason. EMPTY: no copy is accepted. This script never adds to it.
ACCEPTED_SURVIVORS = {}

LABELS = {
    'kind': 'record, NOT gate evidence',
    'gate_accepted': False,
    'end_to_end': False,
    'native_check': 'NATIVE CHECK: every engine verdict (src/primitives_v2/*.rs: rate_window, ledger_graph, taint_egress, farkas, the '
                    'engine, the store, the clock, cosign TTL) and the Goal 20 airlock engine used for the money vectors. Unproved Rust.',
    'finite_test': 'FINITE TEST: every suite case, every changed copy, the demo runs, the differential replays of the Dafny-computed '
                   'vectors against the engines, on one machine. A test count is not a proof.',
    'proved_core': [
        {'source': FARKAS_DFY, 'statement': 'FarkasCert.Soundness (with CheckCert ensures ok == Accepts(A, b, y)): if Accepts(A, b, y), '
                                            'then no non-negative INTEGER vector x satisfies A x >= b',
         'does_not_say': 'nothing about rational or real x; no completeness (an integer-infeasible system can be rational-feasible, then '
                         'no certificate exists); nothing about any solver; nothing about src/primitives_v2/farkas.rs, which mirrors '
                         'Accepts and is tied to it only by the FINITE differential test of test_farkas.py'},
        {'source': 'domains/compiled_policies/*.dfy (four generated models)',
         'statement': 'for each MODEL: its lemmas (Decide gives Post; NoChoice: two results with Post are equal; the property lemmas of '
                      'the module) verify with 0 errors and an empty audit; spec clearing gives NO_CHOICE (and ACCEPTS for the '
                      'witness module)',
         'does_not_say': 'nothing about the Rust engines (src/airlock for money, src/primitives_v2 for rate_window and transfer): '
                         'they are not proved and not compiled from Dafny; the tie is the FINITE differential replay of the '
                         'vectors; the generator policy_to_dfy.py is a TRUSTED ASSUMPTION (unverified Python); the transfer model '
                         'covers only the two-account transfer op'},
    ],
    'stubs_and_not_built': ['the signature check of the cosign TTL module (src/primitives_v2/cosign_ttl.rs) is a STUB '
                            '(NOT_IMPLEMENTED why=COSIGN_SIGNATURE); only the TTL rule is implemented and tested',
                            'the TypeScript wrapper of the primitives SDK is NOT built (only sdk/py/forge_primitives.py exists)'],
    'trusted': ['rustc 1.92.0 and the Rust standard library', 'the pinned Dafny 4.11.0 (verifier, Python back end, runtime) and Z3 4.12.1',
                'the Python interpreter', 'the macOS kernel, file system and drive (F_FULLFSYNC, flock); a SIGKILL is not a power loss',
                'scripts/spec_clearing.py and gate/expected-audit.md of the main checkout (read only)',
                'the generator src/primitives_v2/py/policy_to_dfy.py (TRUSTED ASSUMPTION)'],
}


class Failed(Exception):
    pass


class NotRun(Exception):
    pass


def require(cond, msg):
    if not cond:
        raise Failed(msg)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def canonical(obj):
    return (json.dumps(obj, sort_keys=True, separators=(',', ':'), ensure_ascii=True) + '\n').encode()


def env():
    return dict(os.environ, PYTHONDONTWRITEBYTECODE='1')


def run(argv, cwd=ROOT, timeout=3600, **kw):
    return subprocess.run([str(a) for a in argv], cwd=str(cwd), capture_output=True, text=True, errors='replace',
                          env=kw.pop('env', env()), timeout=timeout, **kw)


class Meter:
    """Times and other timing-dependent values: measurements.json only, never the bundle."""
    def __init__(self):
        self.data = {}

    def put(self, key, value):
        self.data[key] = value


M = Meter()


# --------------------------------------------------------------------------------------------------------- Dafny slot
def slot_busy():
    """A process whose command line matches SLOT holds the slot, except a shell, pgrep or grep: a shell whose `-c`
    text merely NAMES the pattern (for example the loop that started this script) must not block it."""
    p = subprocess.run(['ps', '-ax', '-o', 'pid=,command='], capture_output=True, text=True)
    pat = re.compile(SLOT)
    for line in p.stdout.splitlines():
        pid, _, cmd = line.strip().partition(' ')
        first = os.path.basename(cmd.split(' ', 1)[0]).lstrip('-')
        if int(pid) == os.getpid() or first in ('sh', 'bash', 'zsh', 'pgrep', 'grep', 'tail'):
            continue
        if pat.search(cmd):
            return True
    return False


def wait_slot(label, limit=3600):
    waited = 0
    while slot_busy():
        if waited >= limit:
            raise NotRun('NOT RUN: %s: the Dafny slot was not free in %d min' % (label, limit // 60))
        time.sleep(30)
        waited += 30
    M.put('slot_wait_s/' + label, waited)


def dafny(args, label, log):
    if not Path(DAFNY).is_file():
        raise NotRun('NOT RUN: the pinned Dafny is missing at %s' % DAFNY)
    wait_slot(label)
    t = time.monotonic()
    p = run([DAFNY] + args, cwd=DAFNY_ROOT, timeout=7200)
    M.put('dafny_s/' + label, round(time.monotonic() - t, 1))
    log.write_text((log.read_text() if log.exists() else '') + '$ dafny %s\nexit %d\n%s%s\n' % (' '.join(args), p.returncode, p.stdout, p.stderr))
    return p


# --------------------------------------------------------------------------------------------------------- build
def strip_rust_comments(text):
    out = []
    for line in text.splitlines():
        code, quoted, i = '', False, 0
        while i < len(line):
            c = line[i]
            if c == '"' and (i == 0 or line[i - 1] != '\\'):
                quoted = not quoted
            if not quoted and line.startswith('//', i):
                break
            code += c
            i += 1
        out.append(code)
    return out


def rust_files():
    return sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / ENGINE_SRC).glob('*.rs')) + [AIRLOCK_SRC + '/json.rs', AIRLOCK_SRC + '/pin.rs']


def rust_rules():
    uses, unsafe, extern = [], [], []
    for name in rust_files():
        code = strip_rust_comments((ROOT / name).read_text())
        local = set(re.findall(r'\b(?:enum|struct|mod|trait|type|fn|const|static)\s+([A-Za-z_]\w*)', '\n'.join(code)))
        for n, line in enumerate(code):
            bare = re.sub(r'"(?:[^"\\]|\\.)*"', '""', re.sub(r"'(?:[^'\\]|\\.)'", "''", line))   # string and char literal contents removed
            if re.search(r'\bunsafe\b', bare):
                unsafe.append('%s:%d' % (name, n + 1))
            if re.search(r'\bextern\s+crate\b', line):
                extern.append('%s:%d' % (name, n + 1))
            m = re.match(r'\s*(?:pub(?:\([a-z]+\))?\s+)?use\s+([A-Za-z_]\w*)', line)
            if m:
                uses.append(m.group(1))
                require(m.group(1) in ('std', 'core', 'alloc', 'crate', 'self', 'super') or m.group(1) in local,
                        'SOURCE: %s:%d: `use` from %r (not std, crate, self, super or an item of the file)' % (name, n + 1, m.group(1)))
    first = (ROOT / ENGINE_SRC / 'main.rs').read_text().splitlines()[0]
    require(first == '#![forbid(unsafe_code)]', 'SOURCE: line 1 of main.rs is %r, not #![forbid(unsafe_code)]' % first)
    require(unsafe == [], 'SOURCE: the word unsafe in code: %r' % unsafe)
    require(extern == [], 'SOURCE: extern crate: %r' % extern)
    tracked = run(['git', 'ls-files']).stdout.split('\n')
    cargo = sorted(f for f in tracked if f.startswith(('src/', 'sdk/', 'examples/universal_self_repair/', 'domains/compiled_policies/',
                                                       'tests/primitives_v2/')) and Path(f).name.startswith('Cargo.'))
    cargo += [f for f in ('Cargo.toml', 'Cargo.lock') if (ROOT / f).exists()]
    cargo += sorted(p.relative_to(ROOT).as_posix() for p in (ROOT / ENGINE_SRC).rglob('Cargo.*'))
    require(cargo == [], 'SOURCE: a Cargo file exists: %r' % cargo)
    return {'files': len(rust_files()), 'main_rs_line_1': first, 'unsafe_in_code': 0, 'extern_crate': 0, 'cargo_files': 0,
            'use_roots': sorted(set(uses))}


def python_rules():
    allowed = set(sys.stdlib_module_names) | set(REPO_MODULES)
    seen = {}
    for name in PYTHON_FILES:
        tree = ast.parse((ROOT / name).read_text(), name)
        mods = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                mods |= {a.name.split('.')[0] for a in node.names}
            elif isinstance(node, ast.ImportFrom):
                require(node.level == 0, 'SOURCE: %s has a relative import' % name)
                mods.add(node.module.split('.')[0])
        bad = sorted(mods - allowed)
        require(bad == [], 'SOURCE: %s imports %r (not the standard library, not a named repository module)' % (name, bad))
        seen[name] = sorted(mods & set(REPO_MODULES))
    return {'files': len(PYTHON_FILES), 'non_stdlib_imports': {k: v for k, v in seen.items() if v}, 'allowed_non_stdlib': REPO_MODULES}


def rustc(main_rs, out, seams=False):
    cmd = [RUSTC] + RUSTC_FLAGS + (['--cfg', 'test_seams'] if seams else []) + [main_rs, '-o', out]
    return run(cmd, timeout=3600)


def build_bins(work):
    """The three binaries of an attempt under work/bin. Returns {name: path}."""
    out = work / 'bin'
    out.mkdir(parents=True, exist_ok=True)
    bins = {}
    for name, src, seams in (('primitives-engine', ENGINE_SRC + '/main.rs', False), ('primitives-engine-seams', ENGINE_SRC + '/main.rs', True),
                             ('airlock-engine', AIRLOCK_SRC + '/main.rs', False)):
        t = time.monotonic()
        p = rustc(src, out / name, seams)
        M.put('rustc_s/' + name, round(time.monotonic() - t, 1))
        require(p.returncode == 0, 'BUILD: %s: rustc exit %d\n%s' % (name, p.returncode, p.stderr[-2000:]))
        require(p.stderr.strip() == '' or name == 'airlock-engine', 'BUILD: %s: rustc printed warnings\n%s' % (name, p.stderr[-2000:]))
        bins[name] = out / name
    return bins


def additive():
    # `main` of this clone can lag behind `origin/main` (seen 2026-11-20: local main 9 commits behind). Take the merge-base
    # with each ref that exists and use the NEWER one (the other is its ancestor); a stale local main would otherwise
    # count the files changed on main since then as changes of this branch.
    bases = {}
    for ref in ('main', 'origin/main'):
        mb = run(['git', 'merge-base', 'HEAD', ref])
        if mb.returncode == 0:
            bases[ref] = mb.stdout.strip()
    require(bases, 'ADDITIVE: no merge-base with main or origin/main')
    ref, base = sorted(bases.items())[0]
    for r, b in bases.items():
        if b != base and run(['git', 'merge-base', '--is-ancestor', base, b]).returncode == 0:
            ref, base = r, b
    for r, b in bases.items():
        require(b == base or run(['git', 'merge-base', '--is-ancestor', b, base]).returncode == 0,
                'ADDITIVE: the merge-bases with main and origin/main are not on one line: %r' % bases)
    diff = run(['git', 'diff', '--no-renames', '--name-status', base])
    require(diff.returncode == 0, 'ADDITIVE: git diff exit %d' % diff.returncode)
    added, modified = [], []
    for line in diff.stdout.splitlines():
        status, path = line.split('\t', 1)
        (added if status == 'A' else modified).append((status, path))
    for path in run(['git', 'ls-files', '--others', '--exclude-standard']).stdout.splitlines():
        added.append(('?', path))
    paths = [p for _, p in added + modified]
    protected = sorted(p for p in paths if p.startswith(PROTECTED_DIRS) or p in PROTECTED_FILES)
    bad_mod = sorted('%s %s' % (s, p) for s, p in modified if p not in ALLOWED_MODIFIED)
    for s, p in modified:
        print('  ADDITIVE: modified existing file: %s %s%s' % (s, p, '' if p in ALLOWED_MODIFIED else '  <- NOT ALLOWED'))
    require(bad_mod == [], 'ADDITIVE: existing tracked files changed (only %s may be): %r' % (', '.join(ALLOWED_MODIFIED), bad_mod))
    require(protected == [], 'ADDITIVE: changed or added paths under protected paths: %r' % protected)
    return {'merge_base_with_main': base, 'main_ref_used': ref,'added_files': sorted(p for _, p in added),
            'modified_files': sorted('%s %s' % (s, p) for s, p in modified), 'untracked_not_ignored': sorted(p for s, p in added if s == '?'),
            'protected_paths_touched': 0,
            'protected': list(PROTECTED_DIRS) + list(PROTECTED_FILES), 'allowed_modified': list(ALLOWED_MODIFIED)}


def case_build(work):
    work.mkdir(parents=True, exist_ok=True)
    rules = {'rust': rust_rules(), 'python': python_rules()}
    v = run([RUSTC, '-V']).stdout.strip()
    require(v == RUSTC_VERSION, 'TOOLCHAIN: rustc is %r, pinned %r' % (v, RUSTC_VERSION))
    bins = build_bins(work)
    again = work / 'rebuild'
    again.mkdir()
    identical = {}
    for name, seams in (('primitives-engine', False), ('primitives-engine-seams', True)):
        p = rustc(ENGINE_SRC + '/main.rs', again / name, seams)
        require(p.returncode == 0, 'BUILD: second build of %s: exit %d' % (name, p.returncode))
        identical[name] = (again / name).read_bytes() == bins[name].read_bytes()
    require(all(identical.values()), 'BUILD: the two builds differ: %r' % identical)
    control = work / 'unsafe_control'
    (control / 'src/primitives_v2').mkdir(parents=True)
    (control / 'src/airlock').mkdir(parents=True)
    for f in (ROOT / ENGINE_SRC).glob('*.rs'):
        shutil.copyfile(f, control / 'src/primitives_v2' / f.name)
    for f in ('json.rs', 'pin.rs'):
        shutil.copyfile(ROOT / AIRLOCK_SRC / f, control / 'src/airlock' / f)
    with open(control / 'src/primitives_v2/main.rs', 'a') as fh:
        fh.write('\nfn unsafe_control() -> u8 { unsafe { *(1 as *const u8) } }\n')
    refused = rustc(control / 'src/primitives_v2/main.rs', control / 'out')
    require(refused.returncode != 0 and 'unsafe' in refused.stderr and not (control / 'out').exists(),
            'CONTROL: a copy with an unsafe block compiled (exit %d)' % refused.returncode)
    shutil.rmtree(control)
    add = additive()
    return {'source_rules': rules, 'rustc': v,
            'builds': {n: {'command': ['rustc'] + RUSTC_FLAGS + (['--cfg', 'test_seams'] if n.endswith('seams') else []) +
                           [(AIRLOCK_SRC if n == 'airlock-engine' else ENGINE_SRC) + '/main.rs', '-o', '<attempt>/bin/' + n],
                           'exit': 0, 'sha256': sha(p.read_bytes())} for n, p in sorted(bins.items())},
            'second_build_byte_identical': identical,
            'unsafe_control': {'what': 'the engine sources with one unsafe block appended to main.rs, the same command',
                               'compile_exit': refused.returncode, 'binary_written': False},
            'additive': add}, bins


# --------------------------------------------------------------------------------------------------------- suites
def case_names(suite):
    text = (ROOT / 'tests/primitives_v2' / (suite + '.py')).read_text()
    if suite == 'test_demo':
        spec = importlib.util.spec_from_file_location('demo_for_names', str(ROOT / DEMO))
        mod = importlib.util.module_from_spec(spec)
        sys.path.insert(0, str(ROOT / 'sdk/py'))
        spec.loader.exec_module(mod)
        return ['cli_exit', 'determinism', 'alt_params', 'seeded_params'] + ['canary:' + n for n in sorted(mod.CANARIES)] + ['canary_coverage', 'missing_engine']
    block = text[text.index('\nCASES = ['):]
    block = block[:block.index(']\n') + 1]
    return re.findall(r"\('([a-z_0-9]+)', case_\w+\)", block)


def farkas_py(work):
    """dafny build --target py FarkasCert.dfy (the Dafny-compiled predicate for test_farkas and mutants_p9 part A)."""
    out = work / 'farkas'
    folder = work / 'farkas-py'
    if (folder / 'FarkasCert.py').is_file():
        return folder
    p = dafny(['build', '--target', 'py', str(ROOT / FARKAS_DFY), '--no-verify', '--output', str(out)], 'farkas-py-build', work / 'dafny.log')
    require(p.returncode == 0 and (folder / 'FarkasCert.py').is_file(), 'DAFNY: build --target py FarkasCert.dfy exit %d' % p.returncode)
    return folder


def suite_argv(suite, bins, work, fpy):
    t = ROOT / 'tests/primitives_v2' / (suite + '.py')
    e = bins['primitives-engine']
    if suite == 'test_engine':
        return [PY, t, e, bins['primitives-engine-seams'], '--work', work]
    if suite == 'test_farkas':
        return [PY, t, e, '--work', work, '--dafny-py', fpy]
    if suite == 'test_policy_to_dfy':
        return [PY, t, '--seams-engine', bins['primitives-engine-seams'], '--airlock-engine', bins['airlock-engine'], '--ledger-engine', e, '--work', work]
    if suite == 'test_demo':
        return [PY, t, e]
    return [PY, t, e, '--work', work]


def case_suite(work, bins):
    work.mkdir(parents=True, exist_ok=True)
    fpy = farkas_py(work)
    out = {}
    failed = []
    for suite in SUITES:
        w = work / suite
        w.mkdir()
        if suite == 'test_policy_to_dfy':
            wait_slot('test_policy_to_dfy-start')
        t = time.monotonic()
        try:
            p = run(suite_argv(suite, bins, w, fpy), timeout=6 * 3600)
            code, text = p.returncode, p.stdout + p.stderr
        except subprocess.TimeoutExpired:
            code, text = -1, 'TIMEOUT'
        M.put('suite_s/' + suite, round(time.monotonic() - t, 1))
        (work / (suite + '.log')).write_text(text)
        results = {}
        for line in text.splitlines():
            m = re.match(r'^(PASS|FAIL) (\S+)', line)
            if m:
                require(m.group(2) not in results, 'SUITE %s: case %s printed twice' % (suite, m.group(2)))
                results[m.group(2)] = m.group(1)
        expected = case_names(suite)
        bad = sorted(n for n in expected if results.get(n) != 'PASS')
        extra = sorted(set(results) - set(expected))
        ok = code == 0 and not bad and not extra
        print('  %-20s exit %d, %d of %d cases PASS%s' % (suite, code, sum(1 for n in expected if results.get(n) == 'PASS'), len(expected),
                                                       '' if ok else '; not PASS: %s; unexpected: %s' % (bad, extra)), flush=True)
        for line in text.splitlines():
            if line.startswith('FAIL '):
                print('    ' + line[:400], flush=True)
        if not ok:
            failed.append(suite)
        out[suite] = {'exit_code': code, 'cases': {n: results.get(n, 'MISSING') for n in expected}, 'unexpected_cases': extra}
    require(not failed, 'SUITE: not passed: %s' % failed)
    return out, fpy


# --------------------------------------------------------------------------------------------------------- proofs
def verify_and_audit(dfy, label, work, log):
    p = dafny(['verify', str(dfy)] + DAFNY_OPTIONS, 'verify-' + label, log)
    m = re.search(r'finished with (\d+) verified, (\d+) errors?', p.stdout)
    require(p.returncode == 0 and m and m.group(2) == '0', 'PROOFS: dafny verify %s exit %d (%s)' % (label, p.returncode, m.group(0) if m else 'no summary'))
    report = work / ('audit-%s.md' % label)
    shutil.copyfile(BASELINE, report)
    a = dafny(['audit', str(dfy), '--report-format', 'md', '--report-file', str(report), '--compare-report'], 'audit-' + label, log)
    equal = report.read_bytes() == BASELINE.read_bytes()
    require(a.returncode == 0 and equal, 'PROOFS: dafny audit %s exit %d; report equal to the empty baseline: %s' % (label, a.returncode, equal))
    return {'file': str(Path(dfy).relative_to(ROOT)) if str(dfy).startswith(str(ROOT)) else Path(dfy).name, 'sha256': sha(Path(dfy).read_bytes()),
            'verify_exit': 0, 'verified': int(m.group(1)), 'errors': 0, 'audit_exit': a.returncode, 'audit_equals_empty_baseline': True}


def clearing_snapshot():
    snap = {}
    for root in (ROOT, DAFNY_ROOT):
        d = root / 'clearing'
        for p in sorted(d.rglob('*')) if d.is_dir() else []:
            if p.is_file():
                snap['%s:%s' % (root, p.relative_to(root))] = sha(p.read_bytes())
    return snap


def case_proofs(work):
    work.mkdir(parents=True, exist_ok=True)
    log = work / 'dafny.log'
    require(BASELINE.is_file(), 'PROOFS: no baseline %s' % BASELINE)
    vers = run([DAFNY, '--version'], cwd=DAFNY_ROOT).stdout.strip()
    out = {'dafny_version': vers, 'options': DAFNY_OPTIONS, 'verify': {}, 'determinism': {}, 'vectors': {}, 'clearing': {}}
    out['verify']['FarkasCert'] = verify_and_audit(ROOT / FARKAS_DFY, 'FarkasCert', work, log)
    gen = work / 'gen'
    gen.mkdir()
    for pol in POLICIES:
        texts = set()
        for seed in range(16):
            d = work / ('gen-seed%d' % seed)
            p = run([PY, GENERATOR, 'gen', 'domains/compiled_policies/policies/%s.json' % pol, '--out', d], env=dict(env(), PYTHONHASHSEED=str(seed)))
            require(p.returncode == 0 and p.stdout.startswith('GENERATED %s.dfy ' % MODELS[pol]), 'PROOFS: gen %s exit %d %r' % (pol, p.returncode, p.stdout[:200]))
            texts.add((d / (MODELS[pol] + '.dfy')).read_bytes())
        committed = (ROOT / 'domains/compiled_policies' / (MODELS[pol] + '.dfy')).read_bytes()
        require(len(texts) == 1, 'PROOFS: gen %s: %d different texts in 16 processes' % (pol, len(texts)))
        require(texts == {committed}, 'PROOFS: gen %s differs from the committed domains/compiled_policies/%s.dfy' % (pol, MODELS[pol]))
        (gen / (MODELS[pol] + '.dfy')).write_bytes(committed)
        out['determinism'][pol] = {'processes': 16, 'hash_seeds': '0..15', 'distinct_texts': 1, 'equal_to_committed': True, 'sha256': sha(committed)}
    for seed in range(16):
        shutil.rmtree(work / ('gen-seed%d' % seed))
    for pol in POLICIES:
        out['verify'][MODELS[pol]] = verify_and_audit(ROOT / 'domains/compiled_policies' / (MODELS[pol] + '.dfy'), MODELS[pol], work, log)
    for pol in POLICIES:
        wait_slot('vectors-' + pol)
        t = time.monotonic()
        p = run([PY, GENERATOR, 'vectors', 'domains/compiled_policies/policies/%s.json' % pol, '--out', gen, '--work', work / ('vec-' + pol)], timeout=7200)
        M.put('vectors_s/' + pol, round(time.monotonic() - t, 1))
        log.write_text(log.read_text() + '$ policy_to_dfy.py vectors %s\nexit %d\n%s%s\n' % (pol, p.returncode, p.stdout, p.stderr))
        require(p.returncode == 0, 'PROOFS: vectors %s exit %d %r' % (pol, p.returncode, (p.stdout + p.stderr)[-400:]))
        fresh_bytes = (gen / (MODELS[pol] + '.vectors.json')).read_bytes()
        committed_bytes = (ROOT / 'domains/compiled_policies' / (MODELS[pol] + '.vectors.json')).read_bytes()
        # the WHOLE file, byte for byte: its key `dafny` holds no machine path (tool version, relative argv, exit code)
        require(fresh_bytes == committed_bytes, 'PROOFS: vectors %s: the recomputed file differs from the committed '
                'domains/compiled_policies/%s.vectors.json (whole file, byte for byte)' % (pol, MODELS[pol]))
        committed = json.loads(committed_bytes)
        out['vectors'][pol] = {'byte_identical_file': True, 'vectors': len(committed['vectors']), 'sha256': sha(committed_bytes),
                               'dafny_log': committed['dafny']}
    before = clearing_snapshot()
    for pol in POLICIES:
        wait_slot('clear-' + pol)
        t = time.monotonic()
        p = run([PY, GENERATOR, 'clear', 'domains/compiled_policies/policies/%s.json' % pol, '--out', gen, '--work', work / ('clear-' + pol)], timeout=7200)
        M.put('clear_s/' + pol, round(time.monotonic() - t, 1))
        log.write_text(log.read_text() + '$ policy_to_dfy.py clear %s\nexit %d\n%s%s\n' % (pol, p.returncode, p.stdout, p.stderr))
        try:
            rec = json.loads(p.stdout)
        except ValueError:
            rec = {}
        acc = rec.get('acceptance')
        ok = p.returncode == 0 and rec.get('verdict') == 'NO_CHOICE' and acc in ('ACCEPTS', None) and rec.get('proof_passed') is True \
            and rec.get('spec_probe_passed') is True   # the spec probe's `dafny build` of the open spec is EXPECTED to fail (exit 3)
        require(ok, 'PROOFS: clear %s: exit %d verdict %r acceptance %r proof %r probe %r' % (
            pol, p.returncode, rec.get('verdict'), acc, rec.get('proof_passed'), rec.get('spec_probe_passed')))
        out['clearing'][pol] = {'exit': 0, 'verdict': rec['verdict'], 'acceptance': acc, 'proof_passed': True, 'spec_probe_passed': True,
                                'dafny_command_exits': ['%s %d' % (c['argv'][1], c['exit_code']) for c in rec.get('commands', [])], 'claim_members': rec.get('claim', {}).get('members')}
    require(clearing_snapshot() == before, 'PROOFS: a file under clearing/ changed during spec clearing')
    out['clearing_folder_unchanged'] = True
    sc = DAFNY_ROOT / 'scripts/spec_clearing.py'
    out['spec_clearing_source'] = {'path': 'scripts/spec_clearing.py of the main checkout (the pinned toolchain\'s checkout)', 'sha256': sha(sc.read_bytes())}
    return out


# --------------------------------------------------------------------------------------------------------- demo
def case_demo(work, bins):
    work.mkdir(parents=True, exist_ok=True)
    e = bins['primitives-engine']
    docs = []
    for k in (1, 2):
        j = work / ('demo-%d.json' % k)
        t = time.monotonic()
        p = run([PY, DEMO, '--engine', e, '--json', j], timeout=3600)
        M.put('demo_s/run-%d' % k, round(time.monotonic() - t, 1))
        (work / ('demo-%d.log' % k)).write_text(p.stdout + p.stderr)
        require(p.returncode == 0 and j.is_file(), 'DEMO: run %d exit %d\n%s' % (k, p.returncode, (p.stdout + p.stderr)[-2000:]))
        doc = json.loads(j.read_text())
        M.put('demo_measured/run-%d' % k, doc.get('measured'))
        det = {x: y for x, y in doc.items() if x != 'measured'}
        require(det.get('all_checks_pass') is True and det.get('end_to_end') is False, 'DEMO: run %d: all_checks_pass %r end_to_end %r' % (
            k, det.get('all_checks_pass'), det.get('end_to_end')))
        docs.append(canonical(det))
    require(docs[0] == docs[1], 'DEMO: the two runs differ outside the key `measured`')
    t = time.monotonic()
    st = run([PY, DEMO, '--engine', e, '--self-test'], timeout=7200)
    M.put('demo_s/self-test', round(time.monotonic() - t, 1))
    (work / 'self-test.log').write_text(st.stdout + st.stderr)
    lines = [x for x in st.stdout.splitlines() if re.match(r'^(PASS|FAIL) canary ', x)]
    require(st.returncode == 0 and lines and all(x.startswith('PASS') for x in lines), 'DEMO: --self-test exit %d\n%s' % (st.returncode, st.stdout[-2000:]))
    det = json.loads(docs[0])
    return {'runs': 2, 'exit_codes': [0, 0], 'deterministic_part_identical': True, 'deterministic_sha256': sha(docs[0]),
            'checks': det['checks'], 'counts': det['counts'], 'self_test': {'exit': 0, 'canaries': len(lines), 'all_failed_their_named_check': True}}


# --------------------------------------------------------------------------------------------------------- mutations
ROW = re.compile(r'^(\S+)\s+(?:([AB])\s+)?(\S+)\s+(KILLED|NOT KILLED)\s+[\d.]+s removes: ')


def mutant_table(script):
    spec = importlib.util.spec_from_file_location('mutlist_' + script, str(ROOT / 'tests/primitives_v2' / (script + '.py')))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.MUTANTS


def case_mutations(work, bins, fpy):
    work.mkdir(parents=True, exist_ok=True)
    out, survivors, problems = {}, [], []
    for script in MUTANT_SCRIPTS:
        table = mutant_table(script)
        names = [m[0] for m in table]
        argv = [PY, ROOT / 'tests/primitives_v2' / (script + '.py'), '--work', work, '--rustc', RUSTC]
        if script == 'mutants_p9':
            argv += ['--dafny-py', fpy, '--airlock-engine', bins['airlock-engine'], '--seams-engine', bins['primitives-engine-seams']]
            wait_slot('mutants_p9-start')
        t = time.monotonic()
        try:
            p = run(argv, timeout=12 * 3600)
            code, text = p.returncode, p.stdout + p.stderr
        except subprocess.TimeoutExpired:
            code, text = -1, 'TIMEOUT'
        M.put('mutations_s/' + script, round(time.monotonic() - t, 1))
        (work / (script + '.log')).write_text(text)
        rows, controls = {}, []
        for line in text.splitlines():
            if line.startswith('CONTROL '):
                tok = line.split()
                k = next((i for i, x in enumerate(tok) if i > 1 and x in ('PASS', 'FAIL')), None)
                controls.append((' '.join(tok[2:k]) if k else line[:80], tok[k] if k else 'NO STATUS'))
                continue
            m = ROW.match(line)
            if m and m.group(1) in names:
                require(m.group(1) not in rows, 'MUTATIONS: %s printed twice' % m.group(1))
                rows[m.group(1)] = {'family': m.group(2), 'case': m.group(3), 'killed': m.group(4) == 'KILLED', 'line': line}
        errors = [x for x in text.splitlines() if x.startswith('ERROR')]
        missing = [n for n in names if n not in rows]
        bad_controls = [c for c in controls if c[1] != 'PASS']
        not_killed = [n for n in names if n in rows and not rows[n]['killed']]
        for n in not_killed:
            survivors.append({'script': script, 'name': n, 'case': rows[n]['case'], 'accepted': n in ACCEPTED_SURVIVORS})
            M.put('not_killed_line/' + n, rows[n]['line'][:600])
        expect_exit = 0 if not (missing or bad_controls or not_killed or errors) else 1
        if errors or missing or bad_controls or code != expect_exit:
            problems.append('%s: exit %d, errors %r, missing %r, control failures %r' % (script, code, errors[:3], missing[:10], bad_controls))
        print('  %-11s exit %d: %d copies, %d KILLED, %d NOT KILLED, %d missing; controls %d PASS of %d' % (
            script, code, len(names), sum(r['killed'] for r in rows.values()), len(not_killed), len(missing),
            sum(c[1] == 'PASS' for c in controls), len(controls)), flush=True)
        for n in not_killed:
            print('    NOT KILLED%s: %s' % (' (accepted)' if n in ACCEPTED_SURVIVORS else '', rows[n]['line'][:300]), flush=True)
        out[script] = {'exit_code': code, 'copies': len(names), 'killed': sum(r['killed'] for r in rows.values()), 'not_killed': not_killed,
                       'controls_passed': sum(c[1] == 'PASS' for c in controls), 'controls': len(controls),
                       'per_copy': {n: {'compiled': (None if rows.get(n, {}).get('family') == 'B' else n in rows), 'killed': rows.get(n, {}).get('killed', False)}
                                    for n in names}}
    total = sum(v['copies'] for v in out.values())
    killed = sum(v['killed'] for v in out.values())
    unaccepted = [s for s in survivors if not s['accepted']]
    result = {'scripts': out, 'changed_copies': total, 'killed': killed, 'not_killed': survivors,
              'accepted_survivors': ACCEPTED_SURVIVORS, 'directive_minimum': 24,
              'compiled_note': 'compiled=true: the copy was built with rustc (a copy that does not build stops its script as an ERROR of '
                               'the list); compiled=null: a copy of the Python generator (mutants_p9 part B), nothing to compile'}
    print('  mutations: %d of %d killed; NOT KILLED: %s' % (killed, total, ', '.join(s['name'] for s in survivors) or 'none'), flush=True)
    require(not problems, 'MUTATIONS: %s' % '; '.join(problems))
    require(not unaccepted, 'MUTATIONS: NOT KILLED and not accepted: %s' % ', '.join(s['name'] for s in unaccepted))
    require(total >= 24, 'MUTATIONS: only %d changed copies' % total)
    return result


# --------------------------------------------------------------------------------------------------------- evidence
def subject():
    files = [p for p in run(['git', 'ls-files', '--', 'src/primitives_v2', 'tests/primitives_v2', 'examples/universal_self_repair',
                                 'domains/compiled_policies', 'sdk/py/forge_primitives.py', AIRLOCK_SRC + '/json.rs', AIRLOCK_SRC + '/pin.rs']).stdout.splitlines()]
    files += ['scripts/exit_universal_primitives.py']
    return {f: sha((ROOT / f).read_bytes()) for f in sorted(set(files)) if (ROOT / f).is_file()}


def bundle_of(work):
    before = subject()
    build, bins = case_build(work / 'build')
    print('  build: PASS', flush=True)
    suites, fpy = case_suite(work / 'suite', bins)
    print('  suite: PASS', flush=True)
    proofs = case_proofs(work / 'proofs')
    print('  proofs: PASS', flush=True)
    demo = case_demo(work / 'demo', bins)
    print('  demo: PASS', flush=True)
    muts = case_mutations(work / 'mutations', bins, fpy)
    print('  mutations: PASS', flush=True)
    require(subject() == before, 'INPUT_CHANGED: a subject file changed during the checks')
    return {
        'record': 'forge-v1.1-universal-primitives', 'format_version': 1,
        'producer': 'scripts/exit_universal_primitives.py (an EXIT script; not the gate)',
        'labels': LABELS, 'gate_accepted': False, 'end_to_end': False, 'kind': 'record, NOT gate evidence',
        'note': 'A record of real tool runs on one machine. Only deterministic content: hashes, counts, verdicts. Times, waits, paths and '
                'state hashes are in measurements.json, never here.',
        'machine': platform.system() + ' ' + platform.machine(), 'python': platform.python_version(),
        'subject': before, 'build': build, 'suite': suites, 'proofs': proofs, 'demo': demo, 'mutations': muts,
        'counts': {'suites': len(suites), 'suite_cases': sum(len(v['cases']) for v in suites.values()),
                   'changed_copies': muts['changed_copies'], 'killed': muts['killed'], 'not_killed': len(muts['not_killed']),
                   'dafny_files_verified': len(proofs['verify'])},
        'not_run': [],
        'reproduce_cmd': 'python3 scripts/exit_universal_primitives.py --case evidence',
    }


def attempt_folder(case):
    base = BUILD / case
    base.mkdir(parents=True, exist_ok=True)
    n = 1 + max([int(p.name.split('-')[1]) for p in base.glob('attempt-*')] or [0])
    return base / ('attempt-%04d' % n)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--case', required=True, choices=('build', 'suite', 'proofs', 'demo', 'mutations', 'evidence'))
    args = ap.parse_args()
    work = attempt_folder(args.case)
    work.mkdir(parents=True)
    print('UNIVERSAL_PRIMITIVES %s: %s' % (args.case, work.relative_to(ROOT)), flush=True)
    start = time.monotonic()
    result = None
    try:
        if args.case == 'build':
            result, _ = case_build(work)
            print('  builds exit 0 and byte-identical twice; unsafe control exit %d; modified files: %s; added files: %d' % (
                result['unsafe_control']['compile_exit'], result['additive']['modified_files'] or 'none', len(result['additive']['added_files'])))
        elif args.case == 'suite':
            _, bins = case_build(work / 'build')
            result, _ = case_suite(work, bins)
        elif args.case == 'proofs':
            result = case_proofs(work)
            for k, v in result['verify'].items():
                print('  verify %-24s %d verified, 0 errors; audit equals the empty baseline' % (k, v['verified']))
            for k, v in result['clearing'].items():
                print('  clear  %-24s %s %s' % (k, v['verdict'], v['acceptance']))
        elif args.case == 'demo':
            _, bins = case_build(work / 'build')
            result = case_demo(work, bins)
            print('  two runs exit 0, identical outside `measured` (sha256 %s); self-test %d canaries' % (result['deterministic_sha256'], result['self_test']['canaries']))
        elif args.case == 'mutations':
            _, bins = case_build(work / 'build')
            fpy = farkas_py(work)
            result = case_mutations(work / 'copies', bins, fpy)
        else:
            bundles = []
            for k in (1, 2):
                print(' run %d' % k, flush=True)
                M.data = {}
                t = time.monotonic()
                b = bundle_of(work / ('run-%d' % k))
                M.put('wall_s', round(time.monotonic() - t, 1))
                data = canonical(b)
                bundles.append(data)
                (work / ('run-%d' % k) / 'evidence.json').write_bytes(data)
                (work / ('run-%d' % k) / 'measurements.json').write_text(json.dumps(M.data, indent=1, sort_keys=True, default=str) + '\n')
                print('  run %d bundle sha256 %s' % (k, sha(data)), flush=True)
            same = bundles[0] == bundles[1]
            print('  two bundles byte-identical: %s' % same, flush=True)
            require(same, 'EVIDENCE: the two bundles differ')
            (work / 'evidence.json').write_bytes(bundles[0])
            print('  bundle: %s/evidence.json sha256 %s' % (work.relative_to(ROOT), sha(bundles[0])))
    except NotRun as e:
        print('UNIVERSAL_PRIMITIVES %s: %s; end_to_end=false' % (args.case, e))
        return 2
    except Failed as e:
        print('UNIVERSAL_PRIMITIVES %s: FAILED; end_to_end=false; wall %.0f s\n%s' % (args.case, time.monotonic() - start, e))
        return 1
    finally:
        if args.case != 'evidence':
            (work / 'measurements.json').write_text(json.dumps(M.data, indent=1, sort_keys=True, default=str) + '\n')
    if result is not None:
        (work / 'result.json').write_bytes(canonical(result))
    print('UNIVERSAL_PRIMITIVES %s: PASSED; end_to_end=false; wall %.0f s' % (args.case, time.monotonic() - start))
    return 0


if __name__ == '__main__':
    sys.exit(main())

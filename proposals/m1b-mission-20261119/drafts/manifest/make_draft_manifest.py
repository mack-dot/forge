#!/usr/bin/env python3
"""Write m1_manifest_draft.json from values that exist today (W5 draft; not evidence).

Reads only. Digests come from the files. A value that is not available is null, with a note.
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = Path('<HOME>/forge')
BACKUP = 'c003a9827c6bdfb73c220eb15a40b87e8ce3ba60'  # origin/backup/forge-local-2026-11-11 on 2026-11-19
TOOLCHAIN = REPO / '.toolchain/experiments/refund-cakeml-20261104'
FEAS = 'proposals/refund-executable-feasibility'
REPLAY = FEAS + '/m1-chain-replay-20261118'
E4 = REPLAY + '/records/final-cases/e4-0001'


def sha(b):
    return hashlib.sha256(b).hexdigest()


def blob(commit, path):
    return subprocess.run(['git', '-C', str(REPO), 'cat-file', 'blob', f'{commit}:{path}'],
                          capture_output=True, check=True).stdout


def f(path):
    return {'locator': {'file': path}, 'sha256': sha((REPO / path).read_bytes())}


def g(path):
    return {'locator': {'git': {'commit': BACKUP, 'path': path}}, 'sha256': sha(blob(BACKUP, path))}


def t(path):
    return {'locator': {'toolchain': path}, 'sha256': sha((TOOLCHAIN / path).read_bytes())}


loc = json.loads((HERE / 'dat_locations.json').read_text())
walk = json.loads((HERE / 'walk.json').read_text())
ups = json.loads((HERE / 'upstream_hits.json').read_text())

# the closure of the final theory, walked by the parent records inside the .dat files
P = walk['parents']
closure, stack = set(), ['forge_refundSlideProfileA']
while stack:
    x = stack.pop()
    if x in closure or x not in P:
        continue
    closure.add(x)
    stack += [p for p, _ in P[x]]

theories = []
for name in sorted(closure):
    v = loc[name]
    where = v['where']
    if where.startswith('LOCAL:'):
        dat = {'locator': {'file': where[6:]}, 'sha256': v['dat_sha256']}
    else:
        dat = {'locator': {'git': {'commit': BACKUP, 'path': where}}, 'sha256': v['dat_sha256']}
    theories.append({'theory': name, 'dat': dat, 'sig_sha256': v['sig_sha256']})
# the final theory: use the tracked copy on main
for th in theories:
    if th['theory'] == 'forge_refundSlideProfileA':
        th['dat'] = f(E4 + '/theory-export/forge_refundSlideProfileATheory.dat')

upstream = []
reached_up = {p for x in closure for p, _ in P[x] if p not in P}
for name in sorted(reached_up):
    rel = ups[name][0][0]
    upstream.append({'theory': name, 'dat': t(rel)})

PREMISES = [
    ['P1', 'refund_entry_pre_sl sl s h stk e'],
    ['P2', 'aligned 3 e'],
    ['P3', 'h ≤₊ e'],
    ['P4', '8192w ≤₊ e − h'],
    ['P5', 'refund_heap_clear_sl sl h e'],
    ['P6', 'envmc.prog_addresses = refund_mem_dm_sl sl h e'],
    ['P7', 'refund_env_ok_sl sl envmc'],
    ['P8', 'stdin_content fs = SOME (explode (sexp_to_string (refund_request charge request original remaining enabled opened candidate amount reason)))'],
    ['P9', 'wfcl cl'],
    ['P10', 'wfFS fs'],
    ['P11', 'STD_streams fs'],
]

D = 'proposals/m1-owner-review-20261119/OWNER_DECISIONS.md'
PROFILE = [
    ('A-R1', 'assumption', 'Q1', 'the published CakeML FFI oracle basis_ffi models the file calls'),
    ('A-R2', 'exclusion', 'Q2', 'no OS read error (EIO, EINTR) on an open readable descriptor; a run-time failure of that kind gives no decision'),
    ('A-R3', 'assumption', 'Q1', 'no other thread, process or signal changes the descriptors'),
    ('A-R4', 'assumption', 'Q1', 'wfcl, wfFS, STD_streams, live numchars'),
    ('A-R5', 'assumption', 'Q1', 'a canonical wire request on standard input'),
    ('A-R6', 'assumption', 'Q1', 'the machine state satisfies installed: code, data and heap are where the theorem says'),
    ('A-R8', 'simulation_assumption', 'Q3b', 'ONE simulation assumption: the native C code of the CakeML basis behaves as the model; not a verified native C implementation'),
    ('A-R9', 'assumption', 'Q1', 'no interference between machine steps'),
    ('A-R10', 'assumption', 'Q1', 'the processor is the L3 ARMv8 model; the loader gives the stated layout'),
    ('A-R13', 'trusted_base', 'Q1', 'the HOL4 kernel, Poly/ML, the published CakeML and L3 definitions'),
    ('A-Q3A', 'assumption', 'Q3a', 'entry state: the loader and C run-time reach cml_main with the image mapped at some slide (unverified)'),
    ('A-Q3C', 'conditional_trust', 'Q3c', 'the ML file reader and the offset tool of U389 are trusted only after independent validation, identity pinning and negative controls'),
    ('A-Q5', 'exclusion', 'Q5', 'absent standard input is outside the theorem; the caller fails closed'),
]
profile_items = [{'id': i, 'kind': k, 'decision_ref': f'{D}#{q}', 'statement': s, 'status': 'APPROVED',
                  'verified': False} for i, k, q, s in PROFILE]

stdout = (REPO / E4 / 'stdout.log').read_text(encoding='utf-8')


def printed(log, name):
    lines = log.split('\n')
    i = lines.index('CHECKED ' + name) + 1
    out = []
    stops = ('Saved theorem', 'CHECKED ', 'MARK ', 'MACHINE_SEM_TERM ', 'INPUT_PREMISE ', 'EXACT_COMPLETE')
    while i < len(lines) and not lines[i].startswith(stops):
        out.append(lines[i])
        i += 1
    return ' '.join(' '.join(out).split())


stmt = printed(stdout, 'refund_profile_a_sl')

m = {
    'manifest_format': 'forge.m1.evidence-manifest/1',
    'subject': 'M1 refund decision program, ARM64 Mach-O, CakeML-compiled',
    'end_to_end': False,
    'notes': [
        'W5 draft of 2026-11-19 under the scratch folder. Not evidence. Not under proposals/.',
        'git locators name commit c003a982 (origin/backup/forge-local-2026-11-11); these files are not on main.',
        '19 of the 71 closure .dat files exist only under results/ on this machine (untracked).',
        'toolchain locators are relative to .toolchain/experiments/refund-cakeml-20261104 on this machine (untracked).',
    ],
    'approved_spec': {
        'contract': f('spec/refund/RefundSpec.dfy'),
        'protocol': f('spec/refund/protocol.md'),
        'lock': f('spec/refund/spec.lock'),
        'approval_record': f('proposals/refund-decision.md'),
        'approval_commit': 'e3aa546f86dc5b43ec8c754792e3db4cb413b410',
    },
    'implementation_sources': [
        dict(role='approved_assess_impl', **f('impl/Refund.dfy')),
        dict(role='boundary_dafny', **g(FEAS + '/byte-boundary-20261104/records/inputs/Boundary.dfy')),
        dict(role='hol_dafny_ast_program', **g(FEAS + '/verified-backend-20261104/refund_kernel/attempt-0003/forge_refundScript.sml')),
        dict(role='whole_program_script', **g(FEAS + '/whole-program-20261104/records/proof-whole-repeat/forge_refundWholeProgScript.sml')),
        dict(role='compile_application_script', **g(FEAS + '/arm8-compile-20261104/records/compile-repeat/forge_refundArm8CompileScript.sml')),
    ],
    'final_theorem': {
        'theory': 'forge_refundSlideProfileA',
        'name': 'refund_profile_a_sl',
        'sig': f(E4 + '/theory-export/forge_refundSlideProfileATheory.sig'),
        'statement_log': f(E4 + '/stdout.log'),
        'statement_sha256': sha(stmt.encode('utf-8')),
        'premises': PREMISES,
    },
    'proof_dependencies': {
        'allowed_tags': ['DISK_THM'],
        'forge_theories': theories,
        'upstream_parents': upstream,
        'replay_comparisons': [f(REPLAY + '/records/comparison.json'), f(REPLAY + '/records/comparison-phase2.json')],
    },
    'toolchain': {
        'pin_source': f('proposals/round2-20261117/m1-rebuild/rebuild.py'),
        'polyml_commit': '4557554077078decce4ce5f90da00a713cfc32e4',
        'hol_commit': '9783a49979c94c401ff8c0e51b2eefae7ea95ae3',
        'cakeml_commit': 'cd9155694c16831373ab695a670794f23282ed62',
        'dafny_build': '4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2',
        'backend_config': 'arm8_target$arm8_config',
        'compile_theorem': {
            'theory': 'forge_refundArm8Compile',
            'name': 'refund_arm8_compiled',
            'theory_log': g(FEAS + '/arm8-compile-20261104/records/compile-0001/theory.log'),
            'assembly': g(FEAS + '/arm8-compile-20261104/records/compile-0001/refund.S'),
        },
    },
    'artifact': {
        'file': f('proposals/forge2-m1-conformance/artifacts/refund-arm64-macho'),
        'size': 238776,
        'format': 'Mach-O 64-bit arm64, MH_PIE, ad hoc linker signature',
        'image_theory': 'forge_refundImage',
        'slices': [
            {'name': 'code', 'offset': 16592, 'length': 130436, 'unit': 'bytes',
             'sha256': '3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb',
             'hol_theorem': 'refund_file_code'},
            {'name': 'bitmaps', 'offset': 180248, 'length': 20248, 'unit': 'bytes (2531 little-endian 64-bit words)',
             'sha256': '68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76',
             'hol_theorem': 'refund_file_bitmaps'},
        ],
    },
    'assumption_profile': {
        'profile': 'A',
        'decision_record': {'locator': {'file': D}, 'sha256': sha((REPO / D).read_bytes())},
        'items': profile_items,
        'premise_ledger': {
            'status': 'DRAFT',
            'record': None,
            'map': {
                'P1': ['A-Q3A', 'A-R6', 'A-R10'], 'P2': ['A-Q3A'], 'P3': ['A-Q3A'], 'P4': ['A-Q3A'],
                'P5': ['A-Q3A', 'A-R6'], 'P6': ['A-R6', 'A-R10'], 'P7': ['A-R8', 'A-R9'],
                'P8': ['A-R5', 'A-Q5'], 'P9': ['A-R4'], 'P10': ['A-R4'], 'P11': ['A-R4'],
            },
            'note': 'map drafted by W5 by reading; NOT reviewed; step I.3 (W3) owns the ledger',
        },
        'conditions': [
            {'item': 'A-Q3C', 'status': 'NOT_DONE', 'record': None,
             'note': 'second, independent extraction of the file bytes and offsets is NOT DONE (OWNER_DECISIONS reading of Q3c)'},
        ],
    },
    'obligations': [
        {'id': 'backend_config_ok', 'status': 'DISCHARGED', 'ref': 'U386 scripts; REVIEW_PACKET section 4; not re-checked by W5'},
        {'id': 'mc_init_ok', 'status': 'DISCHARGED', 'ref': 'U386 scripts; REVIEW_PACKET section 4; not re-checked by W5'},
        {'id': 'O2-slide-generic-chain', 'status': 'DISCHARGED', 'ref': 'refund_profile_a_sl quantifies sl under its premises (U405, U407, U409)'},
        {'id': 'O3-output-equation', 'status': 'DISCHARGED', 'ref': 'U404'},
        {'id': 'O4-joint-premises-every-slide', 'status': 'OPEN', 'ref': 'M1R-1: one constructed state at slide 0x4000 only'},
        {'id': 'O7-absent-stdin', 'status': 'APPROVED_ASSUMPTION', 'ref': 'A-Q5'},
    ],
    'contract_link': {
        'status': 'NOT_ESTABLISHED',
        'review': None,
        'mechanical': None,
        'note': 'all 18 rows NOT REVIEWED on main (REVIEW_PACKET section 3). The model review of step I.2 is a report, not a dated independent review record; it found rows 17 and 18 do not hold as worded.',
    },
    'replays': {
        'chain_same_machine': {'status': 'PASSED', 'record': f(REPLAY + '/MANIFEST.json')},
        'recorded_cases_158': {'status': 'RUNNING', 'record': None},
        'clean': {'status': 'NOT_RUN', 'record': None},
        'independent': {'status': 'NOT_RUN', 'record': None},
    },
    'open_issues': [
        {'id': 'I2-row17', 'status': 'OPEN', 'text': 'no checked statement ties the six outputs to Assess, Decision or plan (step I.2 report)'},
        {'id': 'I2-row18', 'status': 'OPEN', 'text': 'the reader accepts more wire texts than protocol.md allows (step I.2 report; Wave Gate 1)'},
        {'id': 'I2-dafny-axiom', 'status': 'OPEN', 'text': 'bodiless {:axiom} lemma in an included Dafny library; use not determined (step I.2 report)'},
    ],
}
out = HERE / 'm1_manifest_draft.json'
out.write_text(json.dumps(m, indent=1, ensure_ascii=False, sort_keys=False) + '\n', encoding='utf-8')
print('wrote', out, 'closure', len(theories), 'upstream', len(upstream), 'statement_sha256', m['final_theorem']['statement_sha256'])
print(stmt[:200])
sys.exit(0)

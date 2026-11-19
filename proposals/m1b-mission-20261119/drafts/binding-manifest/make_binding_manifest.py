#!/usr/bin/env python3 -I
"""Z8: build the DRAFT refund-slice binding manifest. Every digest is computed here from the files on disk.
It runs no proof tool. Usage: python3 -I make_binding_manifest.py <repo> <scratch-root> <out.json>
The reference values are pinned by the same agent family that produced the evidence (see BINDING_DESIGN.md §6)."""
import ast
import hashlib
import json
import sys
from pathlib import Path

REPO, SCR, OUT = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve(), Path(sys.argv[3])
M = 'proposals/m1b-mission-20261119'
LR = M + '/proofs/linked-refund'
SC = M + '/proofs/sink-core'
RP = 'proposals/refund-executable-feasibility/m1-chain-replay-20261118'
U294 = 'results/round4-m1-replay-20261118/phase3/packets-from-backup/proposals/refund-executable-feasibility/source-model-binding-20261104/records'
EXE = 'proposals/forge2-m1-conformance/artifacts/refund-arm64-macho'
DT = '.toolchain/dafny-4.11.0/dafny'
Z3 = DT + '/z3/bin/z3-4.12.1'


def sha(b):
    return hashlib.sha256(b).hexdigest()


def base(kind):
    return {'repo': REPO, 'scratch': SCR, 'toolchain': REPO}[kind]


def pin(kind, path):
    return {'locator': {kind: path}, 'sha256': sha((base(kind) / path).read_bytes())}


def set_digest(pairs):
    return sha(''.join(f'{p}\t{h}\n' for p, h in sorted(pairs)).encode())


def tree(top):
    out = {}
    for p in sorted(top.rglob('*')):
        if p.is_symlink():
            out[p.relative_to(top).as_posix()] = 'symlink:' + str(p.readlink())
        elif p.is_file():
            out[p.relative_to(top).as_posix()] = sha(p.read_bytes())
    return out


def closure(root, entries):
    import posixpath
    import re
    seen, stack = {}, list(entries)
    while stack:
        rel = stack.pop()
        if rel in seen:
            continue
        data = (root / rel).read_bytes()
        seen[rel] = sha(data)
        for inc in re.findall(r'^\s*include\s+"([^"]+)"', data.decode(), re.M):
            stack.append(posixpath.normpath(posixpath.join(posixpath.dirname(rel), inc)))
    return seen


def gate_argv(entries):
    src = (REPO / 'gate/backends/dafny.py').read_text()
    for node in ast.walk(ast.parse(src)):
        if isinstance(node, ast.Assign) and any(getattr(t, 'id', '') == 'OPTIONS' for t in node.targets):
            opts = ast.literal_eval(node.value)
    return ['{dafny}', 'verify'] + entries + ['{z3}' if o == Z3 else o for o in opts]


def proof(pid, kind, loc_kind, root, entries, summary, controls, runs, runner, pins, **extra):
    r = base(loc_kind) / root
    reached = closure(r, entries)
    folder = tree(r)
    p = {'id': pid, 'kind': kind, 'root': {loc_kind: root}, 'entries': entries,
         'include_closure': [{'path': k, 'sha256': v} for k, v in sorted(reached.items())],
         'include_closure_digest': set_digest(reached.items()),
         'folder_files': [{'path': k, 'sha256': v} for k, v in sorted(folder.items())],
         'folder_digest': set_digest(folder.items()),
         'pins': [{'path': k, 'sha256': reached[k], 'why': w} for k, w in pins],
         'argv': gate_argv(entries), 'expected_exit': 0, 'expected_summary': summary,
         'controls': controls, 'runs': runs, 'runner': runner}
    p.update(extra)
    return p


def main():
    dt = tree(REPO / DT)
    S3_CONTROLS = {'N1-unflatten-swap': 4, 'N1b-flatten-swap': 4, 'N2-amount-plus-one': 4, 'N3a-drop-flat-ensures-1': 4,
                   'N3b-drop-flat-ensures-2': 4, 'N3c-drop-flat-ensures-3': 4, 'N4-count0-authorized': 4,
                   'N5-decode-reads-response': 0}
    MUT = ['N1-drop-fresh-id-check', 'N2-drop-pre-state-check', 'N3a-wrong-arithmetic-double-deduct', 'N3b-wrong-arithmetic-add',
           'N4-commit-on-invalid-signature', 'N5-drop-pinned-ids-check', 'N6-non-injective-id-encoding',
           'N7-claim-every-commit-changes-state', 'N8-two-effects-per-commit']
    s3 = proof('S3-linked-refund', 'source', 'repo', LR + '/inputs', ['LinkedRefund.dfy'],
               'Dafny program verifier finished with 1489 verified, 0 errors',
               [{'name': n, 'diff': pin('repo', f'{LR}/negative/{n}.diff'), 'expected_exit': e} for n, e in S3_CONTROLS.items()],
               [{'record_kind': 'run_check_result', 'by': 'run_check.py dispatch, attempt-0002 (orchestrator, by the build/ location; not confirmed)',
                 'files': {'result': pin('repo', 'build/m1b-linked-refund/attempt-0002/result.json'),
                           'log': pin('repo', LR + '/records/m1b-linked-refund-run2.log')}},
                {'record_kind': 'w9_attempt', 'by': 'worker W9, attempt 04',
                 'files': {'env': pin('scratch', 'm1b/W9/attempts/04/env.txt'), 'output': pin('scratch', 'm1b/W9/attempts/04/output.log'),
                           'sha': pin('scratch', 'm1b/W9/attempts/04/sha256.txt'), 'command': pin('scratch', 'm1b/W9/attempts/04/command.txt'),
                           'closure_list': pin('scratch', 'm1b/W9/audit/reached-sha256.txt')}}],
               {'file': pin('repo', LR + '/run_check.py'), 'controls_name': 'CONTROLS'},
               [('LinkedRefund.dfy', 'the proof file (run_check.py PROOF_SHA256)'),
                ('transport/FlatCore.dfy', 'the flat contract = the input of the U294 export')],
               approved_copies=[{'copy': 'transport/' + a, 'approved': {'repo': a}} for a in
                                ('spec/refund/RefundSpec.dfy', 'impl/Refund.dfy', 'clearing/RefundExact.dfy')])
    s3a = proof('S3a-linked-refund-no-hex', 'source', 'scratch', 'm1b/Y10/S3a-noHex/inputs', ['LinkedRefund.dfy'],
                'Dafny program verifier finished with 1486 verified, 0 errors', [],
                [{'record_kind': 'y10_run', 'by': 'worker Y10 (run1.sh)',
                  'files': {'exit': pin('scratch', 'm1b/Y10/runs/S3a-noHex/exit.txt'), 'out': pin('scratch', 'm1b/Y10/runs/S3a-noHex/out.txt'),
                            'sha': pin('scratch', 'm1b/Y10/runs/S3a-noHex/sha.txt'), 'command': pin('scratch', 'm1b/Y10/run1.sh')}}],
                None, [('LinkedRefund.dfy', 'the same proof file as S3')],
                derived_from={'proof': 'S3-linked-refund', 'target': 'library/Std/Strings.dfy',
                              'diff': pin('repo', LR + '/review-controls/S3a-remove-hex-module.diff')},
                note='the closure lives in scratch only; the repository holds the base closure and a classic diff without a file name')
    u5a = proof('U5a-sink-core', 'source', 'repo', SC + '/inputs', ['sink/SinkCore.dfy'],
                'Dafny program verifier finished with 56 verified, 0 errors',
                [{'name': n, 'mutant': {'file': pin('repo', f'{SC}/mutants/{n}/sink/SinkCore.dfy'), 'replaces': 'sink/SinkCore.dfy'},
                  'expected_exit': 4} for n in MUT],
                [{'record_kind': 'y7_result', 'by': 'worker Y7 (dafny_one.sh)',
                  'files': {'result': pin('scratch', 'm1b/Y7/logs/result-all.json'), 'log': pin('scratch', 'm1b/Y7/logs/main.log')}}],
                {'file': pin('repo', SC + '/run_y7.py'), 'controls_name': 'MUTANTS'},
                [('sink/SinkCore.dfy', 'the sink core proof file')],
                approved_copies=[{'copy': c, 'approved': {'repo': a}} for c, a in (
                    ('model/FinalityProtocol.dfy', 'proposals/forge2-pillar2-finality-protocol/FinalityProtocol.dfy'),
                    ('impl/RefundFinality.dfy', 'impl/RefundFinality.dfy'), ('impl/Refund.dfy', 'impl/Refund.dfy'),
                    ('spec/refund/RefundSpec.dfy', 'spec/refund/RefundSpec.dfy'))])
    S1 = 'proposals/forge2-slice1-refund-finality/records/evidence.json'
    runs = [
        {'id': 'S2-refund-gate', 'record_kind': 'slice1_refund_gate', 'by': 'scripts/exit_slice1.py (Slice 1)', 'files': {'evidence': pin('repo', S1)},
         'bound_files': [pin('repo', 'impl/Refund.dfy'), pin('repo', 'spec/refund/RefundSpec.dfy')]},
        {'id': 'U1-refund-finality', 'record_kind': 'slice1_dafny_verify', 'by': 'scripts/exit_slice1.py (Slice 1)', 'files': {'evidence': pin('repo', S1)},
         'bound_files': [pin('repo', 'impl/RefundFinality.dfy'), pin('repo', 'tests/refund-finality/Bindings.dfy'),
                         pin('repo', 'impl/Refund.dfy'), pin('repo', 'spec/refund/RefundSpec.dfy')]},
        {'id': 'U2U3-suite', 'record_kind': 'slice1_suite', 'by': 'scripts/exit_slice1.py (Slice 1)', 'files': {'evidence': pin('repo', S1)},
         'bound_files': [pin('repo', 'ts/refund-finality/sink.ts'), pin('repo', 'ts/refund-finality/minter.ts')]},
        {'id': 'U4-finality-model', 'record_kind': 'f20_summary', 'by': 'run_checks.py (F2.0)', 'case': 'finality-protocol-model-verifies',
         'files': {'summary': pin('repo', 'proposals/forge2-pillar2-finality-protocol/records/summary-attempt-0002.json')},
         'bound_files': [pin('repo', 'proposals/forge2-pillar2-finality-protocol/FinalityProtocol.dfy')]},
        {'id': 'S5-u294-source', 'record_kind': 'u294_command', 'by': 'U294 (2026-11-04)', 'theorems': ['source_decode', 'source_postconditions', 'source_full_result'],
         'files': {'command': pin('repo', U294 + '/hol-0004/command.json'), 'stdout': pin('repo', U294 + '/hol-0004/stdout.log')}},
        {'id': 'S5-u294-bridge', 'record_kind': 'u294_command', 'by': 'U294 (2026-11-04)', 'theorems': ['source_compiled_fields'],
         'files': {'command': pin('repo', U294 + '/bridge-0001/command.json'), 'stdout': pin('repo', U294 + '/bridge-0001/stdout.log')}},
        {'id': 'X12-conformance', 'record_kind': 'conformance', 'by': 'scripts/exit_m1_conformance.py (Wave Gate 1)',
         'files': {'evidence': pin('repo', 'proposals/forge2-m1-conformance/records/evidence.json')}, 'bound_files': [pin('repo', EXE)]},
        {'id': 'V1-second-extraction', 'record_kind': 'y9_extract_result', 'by': 'worker Y9 (report D9)',
         'files': {'result': pin('repo', M + '/drafts/macho-extraction/extract_result.json')}},
    ]
    for rid, kind, label, log, thms in [
            ('X1-T05', 'm1r1_command', 'T05-forge_refundCertifiedProg', 'T05-forge_refundCertifiedProg.log', ['refund_verified_spec']),
            ('X2-C32', 'm1r1_command', 'C32-source-0006', 'C32-source-0006.stdout.log', ['refund_install_exclusion_compiled']),
            ('X2-C34', 'm1r1_command', 'C34-real-0004', 'C34-real-0004.stdout.log', ['refund_compile_correct_no_handler']),
            ('X14-T06', 'm1r1_command', 'T06-forge_refundWireProg', 'T06-forge_refundWireProg.log', ['refund_render_fields_roundtrip']),
            ('V1-C42', 'm1r1_command', 'C42-image-0001', 'C42-image-0001.stdout.log', ['refund_file_code', 'refund_file_bitmaps'])]:
        runs.append({'id': rid, 'record_kind': kind, 'by': 'M1R-1 replay (same machine)', 'label': label, 'theorems': thms,
                     'files': {'commands': pin('repo', RP + '/records/commands.json'), 'log': pin('repo', f'{RP}/records/logs/{log}'),
                               'replay_manifest': pin('repo', RP + '/MANIFEST.json')}})
    for rid, case, thms in [('X3-e4', 'e4-0001', ['refund_profile_a_sl', 'refund_profile_a_sl_every_machine_run']),
                            ('X4-fs', 'fs-r4-0001', ['refund_profile_a_sl_all_premises_satisfiable_at_0x4000'])]:
        runs.append({'id': rid, 'record_kind': 'hol_case', 'by': 'M1R-1 replay (same machine)', 'theorems': thms,
                     'files': {'command': pin('repo', f'{RP}/records/final-cases/{case}/command.json'),
                               'stdout': pin('repo', f'{RP}/records/final-cases/{case}/stdout.log')}})
    exe = (REPO / EXE).read_bytes()
    slices = [{'name': 'code', 'offset': 16592, 'length': 130436, 'symbols': ['cake_main', '_cake_codebuffer_begin']},
              {'name': 'bitmaps', 'offset': 180248, 'length': 20248, 'symbols': ['cake_bitmaps', '_cake_bitmaps_buffer_begin']}]
    for s in slices:
        s['sha256'] = sha(exe[s['offset']:s['offset'] + s['length']])
    G = M + '/TOP_LEVEL_GRAPH.md'
    reported = [
        ('E3-hosted-run', 'ROADMAP.md', 'run 44454558079 |1|REJECTED'),
        ('S3a-orchestrator-run', G, 'RUN AGAIN BY THE ORCHESTRATOR (2026-11-19T06:29Z)'),
        ('U5a-orchestrator-run', G, "orchestrator's run: exit 0, 56 verified"),
        ('S2-expect-false-run', G, "orchestrator's run: exit 0, 6 verified"),
        ('S4-orchestrator-digests', G, 'digests checked by the orchestrator; now pinned in `run_check.py`'),
        ('X13-prefix-test', G, "8,011 strict prefixes of 68 real outputs: a strict parser accepts 0 (report B3; the worker's run)"),
        ('V3-hash-walk', G, "a hash walk of the real files, 0 mismatches (report B4; the worker's run; same machine)"),
        ('U7-crash-test', G, "486 kills, 0 violations; worker's run"),
        ('V6-sha-assert', G, '`run_case.py`, the conformance script'),
        ('V7-manifest-draft', G, "56 control runs (report II; the worker's runs)"),
        ('X10-exit-reading', G, '`_cml_exit` tests the low 32 bits of x0 (read by the orchestrator)'),
    ]
    D = 'proposals/m1-owner-review-20261119/OWNER_DECISIONS.md'
    assumptions = [
        {'id': 'S7-operator-meaning', 'text': 'Dafny and HOL operator meanings agree on 8 operators, 3 literals, 4 strings', 'approved': False},
        {'id': 'S8-canonical-wire', 'text': 'canonical wire input only', 'approved': True, 'decision': pin('repo', D), 'marker': 'Q5'},
        {'id': 'X5-entry-state', 'text': 'the entry state before cml_main satisfies P1 to P6 (TBI0/SA0 wording is false for real registers, D11)',
         'approved': True, 'decision': pin('repo', D), 'marker': 'Q3a'},
        {'id': 'X6-ffi-contract', 'text': 'premise P7 at ALL call states; probably FALSE (fficlose x3 = 0)', 'approved': False},
        {'id': 'X11-kernel', 'text': 'processor and kernel between steps (L3 model, interference_ok)', 'approved': True,
         'decision': pin('repo', D), 'marker': 'Q1'},
        {'id': 'U6-ed25519', 'text': 'Ed25519 and secrecy of the key', 'approved': False},
        {'id': 'U7-power-loss', 'text': 'durable state after power loss (SQLite defaults, no full fsync)', 'approved': False},
    ]
    node = Path('/opt/homebrew/Cellar/node/24.3.0/bin/node')
    unbound = [
        {'id': 'c-runtime-ranges', 'what': 'C run-time and main (basis_ffi.c) in __text, and the __stubs', 'ranges': [[151552, 153800], [153800, 154064]],
         'why': 'outside both slices; only the whole-file hash covers these bytes; no proof reads them'},
        {'id': 'got-binds', 'what': '__DATA_CONST,__got: 23 binds to libSystem (dyld fills them at load)', 'ranges': [[163840, 164024]],
         'why': 'the bytes on disk are hashed; the values at run time come from dyld and libSystem, which no proof covers'},
        {'id': 'cml-main-stub', 'what': 'cml_main stub, NOP pad and 6 FFI trampolines', 'ranges': [[16384, 16592]],
         'why': 'in the HOL __TEXT but outside the code slice'},
        {'id': 'linkedit', 'what': '__LINKEDIT (fixups, exports, symbols, strings, code signature)', 'ranges': [[212992, 238776]],
         'why': 'read by dyld and by the symbol parser; no proof'},
        {'id': 'sink.ts', 'what': 'ts/refund-finality/sink.ts', 'file': pin('repo', 'ts/refund-finality/sink.ts'),
         'why': 'TEST only (Slice 1 suite); U5b model-to-sink.ts is MISSING'},
        {'id': 'minter.ts', 'what': 'ts/refund-finality/minter.ts', 'file': pin('repo', 'ts/refund-finality/minter.ts'), 'why': 'TEST only (U2)'},
        {'id': 'compiled-js-core', 'what': 'JavaScript compiled from impl/RefundFinality.dfy by the Dafny JS back end',
         'recorded_sha256': '721b4d0622ea905b1eeb3e09299b70d4308dcde52c38cbcac1673be97656607d',
         'why': 'source_to_module_proved=false in the Slice 1 record; the file with this digest is regenerated at run time; not located on disk by Z8'},
        {'id': 'node', 'what': 'pinned Node v24.3.0', 'system_path': str(node), 'recorded_sha256': sha(node.read_bytes()),
         'why': 'runs sink.ts, minter.ts and the compiled core; trusted, not proved'},
        {'id': 'sqlite', 'what': 'SQLite inside Node (node:sqlite, DatabaseSync)', 'why': 'durability is an ASSUMPTION (U7); no separate file to bind'},
        {'id': 'dyld-libsystem', 'what': 'dyld, libSystem, the kernel', 'why': 'outside every proof (X5, X11, V2)'},
        {'id': 'u294-exporter', 'what': 'the patched Dafny exporter build of 2026-11-04 (DafnyDriver.dll 55d26351…)',
         'why': 'no longer on this machine (S4); the export bytes are bound, the exporter is not'},
    ]
    E = {'unbound:' + u['id'] for u in unbound}
    C = [
        ('S1', 'UNBOUND', []), ('S2', 'SOURCE_PROOF', ['S2-refund-gate', 'S2-expect-false-run']),
        ('S3', 'SOURCE_PROOF', ['S3-linked-refund', 'export']), ('S3a', 'SOURCE_PROOF', ['S3a-linked-refund-no-hex', 'S3a-orchestrator-run']),
        ('S4', 'TEST', ['export', 'S4-orchestrator-digests', 'unbound:u294-exporter']), ('S5', 'MODEL', ['S5-u294-source', 'S5-u294-bridge']),
        ('S6', 'UNBOUND', []), ('S7', 'ASSUMPTION', ['S7-operator-meaning']), ('S8', 'ASSUMPTION', ['S8-canonical-wire']),
        ('X1', 'MODEL', ['X1-T05']), ('X2', 'MODEL', ['X2-C32', 'X2-C34']), ('X3', 'MODEL', ['X3-e4', 'executable']),
        ('X4', 'MODEL', ['X4-fs']), ('X5', 'ASSUMPTION', ['X5-entry-state']), ('X6', 'ASSUMPTION', ['X6-ffi-contract']),
        ('X7', 'UNBOUND', []), ('X8', 'UNBOUND', []), ('X9', 'UNBOUND', []), ('X10', 'UNBOUND', ['X10-exit-reading']) ,
        ('X11', 'ASSUMPTION', ['X11-kernel', 'unbound:dyld-libsystem']), ('X11e', 'UNBOUND', []),
        ('X12', 'TEST', ['X12-conformance', 'executable']), ('X13', 'REPORTED_ONLY', ['X13-prefix-test']), ('X14', 'MODEL', ['X14-T06']),
        ('X15', 'UNBOUND', []), ('X16', 'UNBOUND', []),
        ('U1', 'SOURCE_PROOF', ['U1-refund-finality']), ('U2', 'TEST', ['U2U3-suite', 'unbound:minter.ts']),
        ('U3', 'TEST', ['U2U3-suite', 'unbound:sink.ts']), ('U4', 'MODEL', ['U4-finality-model']),
        ('U5a', 'SOURCE_PROOF', ['U5a-sink-core', 'U5a-orchestrator-run']), ('U5b', 'UNBOUND', ['unbound:sink.ts', 'unbound:compiled-js-core', 'unbound:node']),
        ('U6', 'ASSUMPTION', ['U6-ed25519']), ('U7', 'ASSUMPTION', ['U7-power-loss', 'U7-crash-test', 'unbound:sqlite']), ('U8', 'UNBOUND', []),
        ('V1', 'MODEL', ['V1-C42', 'V1-second-extraction', 'executable']),
        ('V2', 'UNBOUND', ['unbound:c-runtime-ranges', 'unbound:got-binds', 'unbound:linkedit', 'unbound:cml-main-stub', 'unbound:dyld-libsystem']),
        ('V3', 'REPORTED_ONLY', ['V3-hash-walk']), ('V4', 'UNBOUND', []), ('V5', 'UNBOUND', []), ('V6', 'REPORTED_ONLY', ['V6-sha-assert']),
        ('V7', 'REPORTED_ONLY', ['V7-manifest-draft']),
        ('E1', 'UNBOUND', []), ('E2', 'UNBOUND', []), ('E3', 'REPORTED_ONLY', ['E3-hosted-run']), ('E4', 'UNBOUND', []), ('E5', 'UNBOUND', []),
    ]
    assert all(e in E or not e.startswith('unbound:') for _, _, ev in C for e in ev)
    m = {
        'manifest_format': 'forge.m1b.refund-binding-manifest/1',
        'subject': 'Forge refund slice: which exact files are bound to which link of TOP_LEVEL_GRAPH.md, at which evidence class',
        'end_to_end': False,
        'notes': 'DRAFT by worker Z8. Not evidence. M1-B OPEN. The class of a link is computed by the verifier; stated_class is only checked.',
        'reference_values_pinned_by': 'worker Z8 on the same machine and of the same agent family as the producers: consistency, not independence',
        'toolchain': {'dafny_tree': {'toolchain': DT}, 'dafny_tree_digest': set_digest(dt.items()), 'dafny_tree_files': len(dt),
                      'dafny': pin('toolchain', DT + '/dafny'), 'z3': pin('toolchain', Z3),
                      'gate_options_source': pin('repo', 'gate/backends/dafny.py'), 'version': '4.11.0+fcb2042d6d043a2634f0854338c08feeaaaf4ae2'},
        'dafny_proofs': [s3, s3a, u5a],
        'recorded_runs': runs,
        'executable': {'file': pin('repo', EXE), 'size': len(exe), 'slices': slices,
                       'symbol_parser': pin('repo', M + '/drafts/macho-extraction/y9_macho.py'),
                       'outside_slices': [[0, 16592], [147028, 180248], [200496, len(exe)]]},
        'export': {'source': pin('repo', LR + '/inputs/transport/FlatCore.dfy'), 'export_input': pin('repo', U294 + '/export-0003/input.dfy'),
                   'output': pin('repo', U294 + '/export-0003/output.sexp'), 'size': len((REPO / U294 / 'export-0003/output.sexp').read_bytes()),
                   'export_record': pin('repo', U294 + '/export-0003/command.json')},
        'assumptions': assumptions,
        'reported': [{'id': i, 'file': pin('repo', f), 'quote': q} for i, f, q in reported],
        'unbound': unbound,
        'claims': [{'link': L, 'stated_class': s, 'evidence': ev} for L, s, ev in C],
    }
    OUT.write_text(json.dumps(m, indent=1) + '\n')
    print('wrote', OUT, sha(OUT.read_bytes()))


if __name__ == '__main__':
    main()

"""Check one finished case against PASS_CRITERIA.md (worker A4, 2026-11-19). It starts no prover.

Usage: python3 -I -B check.py <CASE-ID> <case-folder-name>
Prints one line 'VERDICT <id> <case> PASS|FAIL|UNDECIDED' and the reasons; exit 0 PASS, 1 FAIL, 2 UNDECIDED.
It reads <case>/command.json (actual_exit, wall_timeout, markers) and <case>/stdout.log only.
A CPU or wall limit stop (actual_exit < 0 or wall_timeout) is UNDECIDED, never a rejection.
"""
import hashlib, json, sys
from pathlib import Path

RUN = Path(__file__).resolve().parent
REC = RUN / 'recorded'

CONTRACT_THMS = ['exported_contract_decode', 'exported_contract_shape', 'exported_ens1_value',
                 'exported_ens2_value', 'exported_ens3_value', 'exported_contract_value',
                 'exported_contract_on_refund_fields', 'exported_contract_exact',
                 'exported_contract_witnesses']
ELIGIBLE_THMS = ['eligible_link_decode', 'eligible_link_shape', 'eligible_link_guard_value',
                 'eligible_link_matches_compiled_guard', 'eligible_link_operators']
# control id -> (expected last FORGE_BEGIN name or None)
CONTROL_STOP = {'NC1': 'exported_ens1_value', 'NC2': 'exported_ens2_value', 'NC3': 'exported_ens3_value',
                'NC4': None, 'NC5': 'exported_ens1_value', 'NC6': None,
                'NS1': 'exported_contract_on_refund_fields', 'NS2': 'exported_contract_on_refund_fields',
                'NS3': 'exported_contract_on_refund_fields'}


def block(lines, start_prefix, end_line):
    """Lines from the first line that starts with start_prefix up to and including end_line."""
    try:
        i = next(k for k, l in enumerate(lines) if l.startswith(start_prefix))
        j = lines.index(end_line, i)
    except (StopIteration, ValueError):
        return None
    return lines[i:j + 1]


def records(lines, key):
    """Multi-line records: a line that starts with key, plus its continuation lines. A continuation
    line starts with a space (the pretty-printer indents it). This excludes the export_theory lines
    ('Exporting theory ...', 'Theory ... took <time> to build'), whose timing differs per run."""
    out, cur = [], None
    for l in lines:
        if l.startswith(key):
            if cur is not None:
                out.append(cur)
            cur = [l]
        elif cur is not None and l.startswith(' '):
            cur.append(l)
        else:
            if cur is not None:
                out.append(cur)
            cur = None
    if cur is not None:
        out.append(cur)
    return ['\n'.join(r) for r in out]


def theorem_audit(lines, names):
    """Each name has FORGE_THEOREM, FORGE_ORACLES DISK_THM, FORGE_AXIOMS (empty), FORGE_HYPOTHESES 0, in order."""
    errs = []
    thms = [l[len('FORGE_THEOREM '):] for l in lines if l.startswith('FORGE_THEOREM ')]
    if thms != names:
        errs.append('FORGE_THEOREM names %r, expected %r' % (thms, names))
    for n in names:
        try:
            i = lines.index('FORGE_THEOREM ' + n)
        except ValueError:
            continue
        tail = lines[i + 1:i + 4]
        if tail != ['FORGE_ORACLES DISK_THM', 'FORGE_AXIOMS ', 'FORGE_HYPOTHESES 0'] and \
           tail != ['FORGE_ORACLES DISK_THM', 'FORGE_AXIOMS', 'FORGE_HYPOTHESES 0']:
            errs.append('tags of %s: %r' % (n, tail))
    return errs


def main():
    cid, cname = sys.argv[1], sys.argv[2]
    case = RUN / cname
    reasons, undecided = [], []
    try:
        cmd = json.loads((case / 'command.json').read_text())
    except Exception as e:
        print('VERDICT %s %s UNDECIDED' % (cid, cname)); print('  no command.json: %s' % e); return 2
    lines = (case / 'stdout.log').read_text(errors='replace').splitlines()
    ex, markers = cmd.get('actual_exit'), cmd.get('markers', [])
    if ex is None or ex < 0 or cmd.get('wall_timeout'):
        undecided.append('limit or signal stop: actual_exit=%r wall_timeout=%r' % (ex, cmd.get('wall_timeout')))
    if not cmd.get('inputs_unchanged_after', False):
        reasons.append('inputs_unchanged_after is not true')
    begins = [l[len('FORGE_BEGIN '):] for l in lines if l.startswith('FORGE_BEGIN ')]
    any_complete = [l for l in lines if l.endswith('_COMPLETE')]

    def need(cond, msg):
        if not cond:
            reasons.append(msg)

    if cid in ('H0', 'H0p'):
        need(ex == 0, 'exit %r, expected 0' % ex)
        need('EXACT_COMPLETE' in markers, 'marker EXACT_COMPLETE missing')
    elif cid in ('R1', 'R2', 'R3'):
        marker, rec, first = {'R1': ('SOURCE_BINDING_COMPLETE', 'hol-0004', 'CHECKED '),
                              'R2': ('SOURCE_RELATION_COMPLETE', 'relation-0001', 'CHECKED '),
                              'R3': ('SOURCE_BRIDGE_COMPLETE', 'bridge-0001', 'CHECKED ')}[cid]
        need(ex == 0, 'exit %r, expected 0' % ex)
        need(marker in markers, 'marker %s missing' % marker)
        rlines = (REC / (rec + '.stdout.log')).read_text().splitlines()
        new_b, old_b = records(lines, first), records(rlines, first)
        need(len(new_b) == {'R1': 5, 'R2': 1, 'R3': 1}[cid] and new_b == old_b,
             'CHECKED records (%d) differ from recorded %s (%d)' % (len(new_b), rec, len(old_b)))
        print('  info: whole stdout byte-equal to recorded %s: %s' % (rec, lines == rlines))
        norm = lambda rs: [' '.join(r.split()) for r in rs]
        print('  info: CHECKED records equal after whitespace normalisation: %s (decides only a pretty-printer'
              ' line-break difference; the plan asks for byte equality)' % (norm(new_b) == norm(old_b)))
        if cid == 'R1':
            dat = case / '.hol/objs/forge_refundSourceBindingTheory.dat'
            if dat.is_file():
                s1 = hashlib.sha1(dat.read_bytes()).hexdigest()
                print('  info: new SourceBinding .dat SHA-1 %s; recorded 2677fe6830467fd05c52227378bef67ac05dd931; equal: %s'
                      % (s1, s1 == '2677fe6830467fd05c52227378bef67ac05dd931'))
            else:
                reasons.append('no .hol/objs/forge_refundSourceBindingTheory.dat')
    elif cid == 'I1':
        need(ex == 0, 'exit %r, expected 0' % ex)
        need('SOURCE_IMPORT_COMPLETE' in markers, 'marker SOURCE_IMPORT_COMPLETE missing')
        rlines = (REC / 'import-0001.stdout.log').read_text().splitlines()
        imp_new = [l for l in lines if l.startswith('IMPORTED ')]
        imp_old = [l for l in rlines if l.startswith('IMPORTED ')]
        need(len(imp_new) == 7 and imp_new == imp_old, 'IMPORTED lines differ from recorded import-0001 (%d lines)' % len(imp_new))
        ax_new = sorted(l for l in lines if l.startswith('CLOSURE_AXIOM '))
        ax_old = sorted(l for l in rlines if l.startswith('CLOSURE_AXIOM '))
        need(ax_new == ax_old, 'CLOSURE_AXIOM set %r differs from recorded %r' % (ax_new, ax_old))
        nodes_new = sorted(l for l in lines if l.startswith('CLOSURE_NODE '))
        nodes_old = sorted(l for l in rlines if l.startswith('CLOSURE_NODE '))
        print('  info: CLOSURE_NODE lines equal to recorded: %s (%d now, %d recorded)'
              % (nodes_new == nodes_old, len(nodes_new), len(nodes_old)))
    elif cid in ('H1', 'H2', 'PC1'):
        need(ex == 0, 'exit %r, expected 0' % ex)
        need('EXPORTED_CONTRACT_COMPLETE' in markers, 'marker EXPORTED_CONTRACT_COMPLETE missing')
        reasons.extend(theorem_audit(lines, CONTRACT_THMS))
        for x in ('dat', 'sig', 'sml'):
            need((case / ('.hol/objs/forge_refundExportedContractTheory.' + x)).is_file(), 'object .%s missing' % x)
        if cid in ('H2', 'PC1'):
            ref = RUN / 'contract-0001' / 'stdout.log'
            if ref.is_file():
                a = records(lines, 'FORGE_STATEMENT ')
                b = records(ref.read_text(errors='replace').splitlines(), 'FORGE_STATEMENT ')
                if cid == 'H2':
                    need(a == b and len(a) == 9, 'FORGE_STATEMENT records differ from contract-0001')
                else:
                    print('  info: PC1 FORGE_STATEMENT records equal to contract-0001: %s' % (a == b))
            else:
                reasons.append('contract-0001/stdout.log missing (run H1 first)')
    elif cid in CONTROL_STOP:
        need(ex is not None and ex > 0, 'exit %r, expected a positive nonzero exit' % ex)
        need('EXPORTED_CONTRACT_COMPLETE' not in lines, 'EXPORTED_CONTRACT_COMPLETE present: CONTROL ACCEPTED')
        need(not any(l.startswith('FORGE_THEOREM ') for l in lines), 'FORGE_THEOREM lines present')
        want = CONTROL_STOP[cid]
        last = begins[-1] if begins else None
        need(last == want, 'last FORGE_BEGIN %r, expected %r' % (last, want))
    elif cid == 'H4':
        need(ex == 0, 'exit %r, expected 0' % ex)
        need('EXPORTED_RENDER_COMPLETE' in markers, 'marker EXPORTED_RENDER_COMPLETE missing')
        need('FORGE_THEOREM exported_contract_on_rendered_output' in lines, 'FORGE_THEOREM line missing')
        for x in ('dat', 'sig', 'sml'):
            need((case / ('.hol/objs/forge_refundExportedRenderTheory.' + x)).is_file(), 'object .%s missing' % x)
    elif cid == 'NR1':
        need(ex is not None and ex > 0, 'exit %r, expected a positive nonzero exit' % ex)
        need('EXPORTED_RENDER_COMPLETE' not in lines, 'EXPORTED_RENDER_COMPLETE present: CONTROL ACCEPTED')
        need('FORGE_THEOREM exported_contract_on_rendered_output' not in lines, 'FORGE_THEOREM present')
    elif cid in ('E0', 'E0r'):
        need(ex == 0, 'exit %r, expected 0' % ex)
        need('ELIGIBLE_LINK_COMPLETE' in lines, 'ELIGIBLE_LINK_COMPLETE line missing (not in runner MARKERS; read from stdout)')
        reasons.extend(theorem_audit(lines, ELIGIBLE_THMS))
        if cid == 'E0r':
            ref = RUN / 'eligible-link-0001' / 'stdout.log'
            if ref.is_file():
                a = records(lines, 'FORGE_STATEMENT ')
                b = records(ref.read_text(errors='replace').splitlines(), 'FORGE_STATEMENT ')
                need(a == b and len(a) == 5, 'FORGE_STATEMENT records differ from eligible-link-0001')
    else:
        print('unknown case id %s' % cid); return 2
    print('  info: actual_exit=%r markers=%r last FORGE_BEGIN=%r *_COMPLETE lines=%r wall=%r'
          % (ex, markers, begins[-1] if begins else None, any_complete, cmd.get('wall_seconds')))
    if undecided:
        verdict, code = 'UNDECIDED', 2
    elif reasons:
        verdict, code = 'FAIL', 1
    else:
        verdict, code = 'PASS', 0
    print('VERDICT %s %s %s' % (cid, cname, verdict))
    for r in undecided + reasons:
        print('  ' + r)
    return code


if __name__ == '__main__':
    sys.exit(main())

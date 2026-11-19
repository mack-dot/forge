"""Make the negative-control inputs for exported_contract_on_refund_fields. DRAFT tool (worker Y2).

Usage: python3 -I make_controls.py <export.sexp> <forge_refundExportedContractScript.sml> <out-folder>

It runs no prover. It writes one mutated copy per control, checks that each edit hits
exactly the expected number of places, and prints the SHA-256 of every file. A control
input is NOT evidence; only the HOL exit of its run is.
"""
import hashlib, json, sys
from pathlib import Path

EXPORT_SHA = '58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d'


def sha(b):
    return hashlib.sha256(b).hexdigest()


def replace_nth(text, old, new, which, expected_total):
    """Replace occurrence number `which` (1-based; 0 = all) of `old`; check the total count."""
    total = text.count(old)
    assert total == expected_total, (old, total, expected_total)
    if which == 0:
        return text.replace(old, new)
    at = -1
    for _ in range(which):
        at = text.index(old, at + 1)
    return text[:at] + new + text[at + len(old):]


def third_clause_span(text):
    """The span of the third ensures clause: the balanced S-expression that starts at
    '(BinOp (Imp) (UnOp (Not)'. It must occur exactly once."""
    head = '(BinOp (Imp) (UnOp (Not)'
    assert text.count(head) == 1
    start = text.index(head)
    depth = 0
    for i in range(start, len(text)):
        depth += {'(': 1, ')': -1}.get(text[i], 0)
        if depth == 0:
            return start, i + 1
    raise AssertionError('unbalanced')


def main():
    export_path, script_path, out = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
    export = export_path.read_bytes()
    assert sha(export) == EXPORT_SHA, 'export bytes differ'
    text = export.decode('ascii')
    script = script_path.read_text()
    out.mkdir(parents=True, exist_ok=False)
    rows = []

    def emit(name, kind, data, must, edit):
        path = out / name
        path.write_bytes(data.encode('utf-8') if isinstance(data, str) else data)
        rows.append({'control': name, 'kind': kind, 'sha256': sha(path.read_bytes()),
                     'expected': must, 'edit': edit})

    le_amount = '(BinOp (Le) (Var "amount") (Var "remaining"))'
    # The ensures come before the body in the export, so occurrence 1 is the contract, 2 the body.
    emit('NC1-amount-lt-in-contract.sexp', 'export',
         replace_nth(text, le_amount, le_amount.replace('(Le)', '(Lt)'), 1, 2),
         'exit 1; stops after FORGE_BEGIN exported_ens1_value', 'occurrence 1 of 2: Le -> Lt (contract only)')
    t = replace_nth(text, '(BinOp (Eq) (Var "outputCharge") (Var "chargeId"))',
                    '(BinOp (Eq) (Var "outputCharge") (Var "requestId"))', 0, 1)
    t = replace_nth(t, '(BinOp (Eq) (Var "outputRequest") (Var "requestId"))',
                    '(BinOp (Eq) (Var "outputRequest") (Var "chargeId"))', 0, 1)
    emit('NC2-ids-swapped-in-contract.sexp', 'export', t,
         'exit 1; stops after FORGE_BEGIN exported_ens2_value', 'clause 2: outputCharge==requestId, outputRequest==chargeId')
    emit('NC3-count-one-when-rejected.sexp', 'export',
         replace_nth(text, '(BinOp (Eq) (Var "intentCount") (Lit (IntL 0)))',
                     '(BinOp (Eq) (Var "intentCount") (Lit (IntL 1)))', 0, 1),
         'exit 1; stops after FORGE_BEGIN exported_ens3_value', 'clause 3: intentCount == 0 -> == 1')
    s, e = third_clause_span(text)
    dropped = text[:s].rstrip(' ') + text[e:]
    emit('NC4-third-clause-dropped.sexp', 'export', dropped,
         'exit 1; ML Fail "Expected exactly three ensures clauses" before any FORGE_BEGIN',
         'clause 3 removed (%d bytes)' % (e - s))
    emit('NC5-reason-literal-in-contract.sexp', 'export',
         replace_nth(text, '"returned_item"', '"returned_itex"', 1, 2),
         'exit 1; stops after FORGE_BEGIN exported_ens1_value', 'occurrence 1 of 2 (contract only)')
    emit('NC6-trailing-bytes.sexp', 'export', text + ' (Extra)',
         'exit 1; ML Fail "Trailing export bytes"', 'append " (Extra)"')
    emit('PC1-body-only-mutation.sexp', 'export',
         replace_nth(text, le_amount, le_amount.replace('(Le)', '(Lt)'), 2, 2),
         'exit 0 and EXPECTED: the contract theorems do not read the body (U294 links the body)',
         'occurrence 2 of 2: Le -> Lt (body only)')

    # Statement controls: the export is unchanged; one edit in the main theorem only.
    main_old = ('  evaluate_exps (exported_contract_state h charge request original remaining enabled\n'
                '      opened candidate amount reason ok a r c q n) env exported_ensures =\n'
                '  (exported_contract_state h charge request original remaining enabled opened\n'
                '      candidate amount reason ok a r c q n,\n'
                '   Rval [BoolV T; BoolV T; BoolV T])``,\n'
                '  strip_tac')
    assert script.count(main_old) == 1, 'main theorem text not found exactly once'

    def stmt(name, new_tail_args, new_result, must, edit):
        new = main_old.replace('ok a r c q n', new_tail_args)
        new = new.replace('Rval [BoolV T; BoolV T; BoolV T]', new_result)
        assert new != main_old
        emit(name, 'script', script.replace(main_old, new), must, edit)

    stmt('NS1-amount-plus-one.sml', 'ok (a + 1) r c q n', 'Rval [BoolV T; BoolV T; BoolV T]',
         'exit 1; stops after FORGE_BEGIN exported_contract_on_refund_fields', 'state uses a + 1')
    stmt('NS2-ids-swapped.sml', 'ok a r q c n', 'Rval [BoolV T; BoolV T; BoolV T]',
         'exit 1; stops after FORGE_BEGIN exported_contract_on_refund_fields', 'state uses (q, c) for (outputCharge, outputRequest)')
    stmt('NS3-wrong-truth-value.sml', 'ok a r c q n', 'Rval [BoolV T; BoolV T; BoolV F]',
         'exit 1; stops after FORGE_BEGIN exported_contract_on_refund_fields', 'claims clause 3 is false')
    render_path = script_path.parent / 'forge_refundExportedRender' 'Script.sml'
    render = render_path.read_text()
    swap_old = 'rest = [] /\\ (ok,a,r,c,q,n) = (ok0,a0,r0,c0,q0,n0) /\\'
    assert render.count(swap_old) == 1, 'render claim not found exactly once'
    emit('NR1-render-ids-swapped.sml', 'render-script',
         render.replace(swap_old, swap_old.replace('(ok0,a0,r0,c0,q0,n0)', '(ok0,a0,r0,q0,c0,n0)')),
         'exit 1; exported_contract_on_rendered_output fails (charge and request read back swapped)',
         'claim (ok,a,r,c,q,n) = (ok0,a0,r0,q0,c0,n0)')
    (out / 'CONTROLS.json').write_text(json.dumps(rows, indent=1) + '\n')
    print(json.dumps(rows, indent=1))


if __name__ == '__main__':
    main()

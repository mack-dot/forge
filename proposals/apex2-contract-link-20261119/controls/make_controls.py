#!/usr/bin/env python3
"""APEX-2 negative controls. Usage: make_controls.py <package-dir> <out-dir>
Writes one folder per control under <out-dir>. Each mutation must apply exactly
once (or the stated number of times); otherwise this script stops.
A HOL control folder is a full copy of hol/ with ONE mutation. A Dafny control
folder holds a mutated copy of FlatCore.dfy or of HolFlatGenerated.dfy.
Standard library only."""
import hashlib, json, pathlib, shutil, sys

pkg = pathlib.Path(sys.argv[1]).resolve()
out = pathlib.Path(sys.argv[2]).resolve()
hol = pkg / 'hol'
FLAT = 'forge_refundFlatContractScript.sml'
EXP = 'forge_refundExportedContractScript.sml'
SEXP = 'FlatCore.sexp'
FLATCORE = pkg.parent / 'm1b-mission-20261119/proofs/slice-theorem/inputs/transport/FlatCore.dfy'
GEN = pkg / 'dafny/HolFlatGenerated.dfy'

def sub(text, old, new, count=1):
    if text.count(old) != count:
        raise SystemExit(f'mutation does not apply {count} time(s): {old!r} found {text.count(old)}')
    return text.replace(old, new)

def sha1(b): return hashlib.sha1(b).hexdigest()

# id, file, old, new, count, target, expected failing theorem (or None), what it tests
HOL_SCRIPT = [
 ('HN1-ids-swapped', FLAT, 'outputCharge = chargeId /\\\n       outputRequest = requestId',
  'outputCharge = requestId /\\\n       outputRequest = chargeId', 1, 'refund_fields_flat_plain',
  'chargeId and requestId swapped in the outputs of flat_plain'),
 ('HN2-maxmoney-plus-one', FLAT, 'original <= 9223372036854775807 /\\', 'original <= 9223372036854775808 /\\', 1,
  'refund_fields_flat_plain', 'MaxMoney + 1 in flat_plain'),
 ('HN3-maxmoney-minus-one', FLAT, 'original <= 9223372036854775807 /\\', 'original <= 9223372036854775806 /\\', 1,
  'refund_fields_flat_plain', 'MaxMoney - 1 in flat_plain'),
 ('HN4-candidate-dropped', FLAT, 'remaining <= original /\\ candidate /\\', 'remaining <= original /\\', 1,
  'refund_fields_flat_plain', 'guard conjunct `candidate` deleted'),
 ('HN5-amount-bound-altered', FLAT, '0 <= amount /\\ amount <= remaining /\\', '0 <= amount /\\ amount <= original /\\', 1,
  'refund_fields_flat_plain', 'guard conjunct amount <= remaining changed to amount <= original'),
 ('HN6-fallback-count-one', FLAT, 'outputRequest = [] /\\ intentCount = 0)``);', 'outputRequest = [] /\\ intentCount = 1)``);', 1,
  'refund_fields_flat_plain', 'fallback answer with intentCount = 1'),
 ('HN7-reason-byte-altered', FLAT, '(reason = [100; 117;', '(reason = [101; 117;', 1,
  'refund_fields_flat_plain', 'first byte of "duplicate_charge" changed in flat_plain'),
 ('HN9-input-ids-swapped', FLAT, 'flat_plain (codes charge) (codes request) original remaining enabled opened\n      candidate amount (codes reason) ok a (codes r) (codes c) (codes q) n``,\n  simp [flat_plain_def, GSYM codes_literals, codes_11,\n        forge_refundCertifiedProgTheory.refund_fields_def,',
  'flat_plain (codes request) (codes charge) original remaining enabled opened\n      candidate amount (codes reason) ok a (codes r) (codes c) (codes q) n``,\n  simp [flat_plain_def, GSYM codes_literals, codes_11,\n        forge_refundCertifiedProgTheory.refund_fields_def,', 1,
  'refund_fields_flat_plain', 'INPUT side only: codes charge and codes request swapped in the statement of FC1'),
 ('HN8-zero-amount-refused', FLAT, '0 <= amount /\\ amount <= remaining /\\', '1 <= amount /\\ amount <= remaining /\\', 1,
  'refund_fields_flat_plain', 'guard conjunct 0 <= amount changed to 1 <= amount (off by one at the lower edge)'),
]
# printer mutants: HOL still proves everything (exit 0 EXPECTED); the generated file must differ from the pin
PRINTER = [
 ('PN1-le-printed-lt', FLAT, 'then bin "<=" (intSyntax.dest_leq tm)', 'then bin "<" (intSyntax.dest_leq tm)', 1,
  'printer: <= printed as <'),
 ('PN2-and-printed-or', FLAT, 'then bin "&&" (dest_conj tm)', 'then bin "||" (dest_conj tm)', 1,
  'printer: /\\ printed as ||'),
 ('PN3-args-reversed', FLAT, 'and bin opr (l, r) = "(" ^ dafny_of_term l ^ " " ^ opr ^ " " ^ dafny_of_term r ^ ")";',
  'and bin opr (l, r) = "(" ^ dafny_of_term r ^ " " ^ opr ^ " " ^ dafny_of_term l ^ ")";', 1,
  'printer: the two arguments of every binary form reversed'),
]
# export mutants. "pin" = leave the SHA-1 pin (the script must refuse); "repin" = set the pin to the mutant (the proof must fail)
EXPORT = [
 ('XN1-export-changed-pin-kept', '(Lit (IntL 9223372036854775807))', '(Lit (IntL 9223372036854775808))', 2, False,
  'Export SHA-1 differs from the pin', 'export bytes changed, pin kept: the script must refuse to start'),
 ('XN2-export-maxmoney-plus-one', '(Lit (IntL 9223372036854775807))', '(Lit (IntL 9223372036854775808))', 2, True,
  'exported_ens1_value', 'MaxMoney + 1 in the export (clause and body), pins moved to the mutant'),
 ('XN3-export-ids-swapped', '(BinOp (Eq) (Var "outputCharge") (Var "chargeId"))) (BinOp (Eq) (Var "outputRequest") (Var "requestId"))',
  '(BinOp (Eq) (Var "outputCharge") (Var "requestId"))) (BinOp (Eq) (Var "outputRequest") (Var "chargeId"))', 1, True,
  'exported_ens2_value', 'chargeId and requestId swapped in ensures clause 2 of the export, pins moved'),
 ('XN5-export-maxmoney-minus-one', '(Lit (IntL 9223372036854775807))', '(Lit (IntL 9223372036854775806))', 2, True,
  'exported_ens1_value', 'MaxMoney - 1 in the export (clause and body), pins moved to the mutant'),
 ('XN4-export-candidate-dropped', None, None, 1, True, 'exported_ens1_value',
  'guard conjunct `candidate` replaced by `enabled` in ensures clause 1 of the export, pins moved'),
]
DAFNY = [
 ('DN1-source-ids-swapped', 'flatcore', [('outputCharge == chargeId && outputRequest == requestId', 'outputCharge == requestId && outputRequest == chargeId', 1),
   ('outputCharge := chargeId;\n      outputRequest := requestId;', 'outputCharge := requestId;\n      outputRequest := chargeId;', 1)],
  'FlatCore.dfy with chargeId/requestId swapped in the outputs (clause and body)'),
 ('DN2-source-maxmoney-plus-one', 'flatcore', [('9223372036854775807', '9223372036854775808', 2)], 'FlatCore.dfy with MaxMoney + 1'),
 ('DN3-source-maxmoney-minus-one', 'flatcore', [('9223372036854775807', '9223372036854775806', 2)], 'FlatCore.dfy with MaxMoney - 1'),
 ('DN4-source-candidate-dropped', 'flatcore', [('candidate && 0 <= amount <= remaining', '0 <= amount <= remaining', 2)], 'FlatCore.dfy without the conjunct `candidate`'),
 ('DN5-source-fallback-count-one', 'flatcore', [('outputRequest == "" && intentCount == 0', 'outputRequest == "" && intentCount == 1', 1),
   ('outputRequest := "";\n      intentCount := 0;', 'outputRequest := "";\n      intentCount := 1;', 1)], 'FlatCore.dfy with fallback intentCount 1'),
 ('DN6-source-reason-altered', 'flatcore', [('"returned_item"', '"returned_items"', 2)], 'FlatCore.dfy with a changed reason literal'),
 ('DN7-generated-edited', 'generated', [('(original <= 9223372036854775807)', '(original <= 9223372036854775808)', 1)], 'HolFlatGenerated.dfy edited by hand (MaxMoney + 1)'),
 ('DN8-generated-ids-swapped', 'generated', [('((outputCharge == chargeId) && ((outputRequest == requestId)', '((outputCharge == requestId) && ((outputRequest == chargeId)', 1)], 'HolFlatGenerated.dfy edited by hand (ids swapped)'),
 ('DN9-generated-maxmoney-minus-one', 'generated', [('(original <= 9223372036854775807)', '(original <= 9223372036854775806)', 1)], 'HolFlatGenerated.dfy edited by hand (MaxMoney - 1)'),
 ('DN10-generated-candidate-dropped', 'generated', [('(candidate && ((0 <= amount)', '(true && ((0 <= amount)', 1)], 'HolFlatGenerated.dfy edited by hand (conjunct candidate replaced by true)'),
 ('DN11-generated-amount-strict', 'generated', [('((0 <= amount) && ((amount <= remaining)', '((0 <= amount) && ((amount <= original)', 1)], 'HolFlatGenerated.dfy edited by hand (amount <= remaining changed to amount <= original)'),
 ('DN12-link-inputs-swapped', 'hollink', [('H.FlatPlain(Codes(chargeId), Codes(requestId), original', 'H.FlatPlain(Codes(requestId), Codes(chargeId), original', 1)], 'HolLink.dfy: the two identifiers swapped on the INPUT side of Plain only'),
 ('DN13-link-outputs-swapped', 'hollink', [('Codes(outputCharge), Codes(outputRequest), intentCount)', 'Codes(outputRequest), Codes(outputCharge), intentCount)', 1)], 'HolLink.dfy: the two identifiers swapped on the OUTPUT side of Plain only'),
]

index = []
def copy_hol(d):
    d.mkdir(parents=True)
    for f in ('Holmakefile', FLAT, EXP, 'forge_refundFlatExportedScript.sml', SEXP):
        shutil.copy(hol / f, d / f)

for cid, f, old, new, n, thm, what in HOL_SCRIPT:
    d = out / cid; copy_hol(d)
    (d / f).write_text(sub((hol / f).read_text(), old, new, n))
    index.append({'control': cid, 'kind': 'hol-statement', 'target': 'forge_refundFlatContractTheory',
                  'expect_exit_nonzero': True, 'expect_text': f'Tactic failure proving "{thm}"', 'what': what})
for cid, f, old, new, n, what in PRINTER:
    d = out / cid; copy_hol(d)
    (d / f).write_text(sub((hol / f).read_text(), old, new, n))
    index.append({'control': cid, 'kind': 'printer', 'target': 'forge_refundFlatContractTheory',
                  'expect_exit_nonzero': False, 'expect_text': 'FLAT_CONTRACT_COMPLETE', 'what': what})
for cid, old, new, n, repin, text, what in EXPORT:
    d = out / cid; copy_hol(d)
    raw = (hol / SEXP).read_bytes()
    if old is None:
        # clause 1 only: the first occurrence of ') (Var "candidate")) (BinOp (And) (BinOp (Le) (Lit (IntL 0)) (Var "amount"))'
        o = b') (Var "candidate")) (BinOp (And) (BinOp (Le) (Lit (IntL 0)) (Var "amount"))'
        if raw.count(o) < 1: raise SystemExit('XN4 does not apply')
        mut = raw.replace(o, o.replace(b'"candidate"', b'"enabled"'), 1)
    else:
        mut = sub(raw.decode(), old, new, n).encode()
    (d / SEXP).write_bytes(mut)
    if repin:
        s = (hol / EXP).read_text()
        s = sub(s, 'val export_sha1_expected = "%s";' % sha1(raw), 'val export_sha1_expected = "%s";' % sha1(mut))
        s = sub(s, 'val export_length_expected = %d;' % len(raw), 'val export_length_expected = %d;' % len(mut))
        (d / EXP).write_text(s)
    index.append({'control': cid, 'kind': 'export', 'target': 'forge_refundExportedContractTheory',
                  'expect_exit_nonzero': True,
                  'expect_text': text if not repin else f'Tactic failure proving "{text}"', 'what': what})
for cid, which, muts, what in DAFNY:
    d = out / cid; d.mkdir(parents=True)
    src = {'flatcore': FLATCORE, 'generated': GEN, 'hollink': pkg / 'dafny/HolLink.dfy'}[which]
    s = src.read_text()
    for old, new, n in muts: s = sub(s, old, new, n)
    (d / src.name).write_text(s)
    index.append({'control': cid, 'kind': 'dafny-' + which, 'expect_exit_nonzero': True,
                  'expect_text': 'HolLink.dfy', 'what': what})
for cid, val in (('DN14-generated-true', 'true'), ('DN15-generated-false', 'false')):
    d = out / cid; d.mkdir(parents=True)
    g = GEN.read_text()
    a = g.index('  {\n    ') + len('  {\n    '); b = g.index('\n  }\n}\n')
    (d / GEN.name).write_text(g[:a] + val + g[b:])
    index.append({'control': cid, 'kind': 'dafny-generated', 'expect_exit_nonzero': True,
                  'expect_text': 'HolLink.dfy', 'what': 'HolFlatGenerated.dfy with the body replaced by ' + val})
for r in index:
    r['files_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((out / r['control']).iterdir())}
(out / 'CONTROLS.json').write_text(json.dumps(index, indent=1) + '\n')
print(len(index), 'controls written')

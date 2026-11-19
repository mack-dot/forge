"""Y12: decode the string literals in the Boogie 'call' contract of AssessFlat (from dafny --bprint) and
compare them with the StrL atoms of the export. A test, not a proof."""
import re, sys
bpl = open(sys.argv[1]).read(); sx = open(sys.argv[2]).read()
i = bpl.index('Call$$FlatRefund.__default.AssessFlat'); j = bpl.index('// frame condition', i)
call = bpl[i:j]
lits = []
for m in re.finditer(r'Seq#Equal\(reason#0,\s*((?:Seq#Build\(\s*)+Seq#Empty\(\): Seq(?:,\s*\$Box\(char#FromInt\(\d+\)\)\)\s*)+)', call):
    lits.append(''.join(chr(int(c)) for c in re.findall(r'char#FromInt\((\d+)\)', m.group(1))))
print('boogie reason literals:', lits)
ex = re.findall(r'\(Lit \(StrL "([^"]*)"\)\)', sx)
ens = sx[:sx.index('(Then')]      # contract part only (before the body)
exl = [s for s in re.findall(r'\(StrL "([^"]*)"\)', ens) if s]
print('export non-empty contract literals:', exl)
print('Seq#Equal count in call contract:', call.count('Seq#Equal'), '; string Eq/Neq in export contract:',
      len(re.findall(r'\(BinOp \((?:Eq|Neq)\) \(Var "(?:chargeId|requestId|reason|outputReason|outputCharge|outputRequest)"\)', ens)))
print('char codes all < 128:', all(ord(c) < 128 for s in lits for c in s))
sys.exit(0 if lits == exl else 1)

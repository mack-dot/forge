#!/usr/bin/env python3
"""Y12 (M1-B, link S7, part 3). DRAFT generator. It writes Mirror.dfy:
  * a Dafny transcription ("mirror") of the HOL definitions value, do_sc, do_uop, value_same_type, do_bop,
    lit_to_val, read_local and evaluate_exp (Lit, Var, UnOp, BinOp cases) from
    cakeml/compiler/dafny/semantics/dafny_semanticPrimitivesScript.sml and dafny_evaluateScript.sml;
  * the three ensures trees of the export, generated from the S-expression file (not from Dafny text);
  * the three ensures clauses of FlatCore.dfy, copied byte for byte from the source text;
  * one lemma per clause: for every environment of byte strings, ints and bools,
      MEval(tree_k, env) == Rval(BoolV(<source clause k>)).
The proof is bottom-up, one assertion per tree node. What it proves is about the MIRROR, not about HOL.
Usage: gen_mirror.py EXPORT.sexp FLATCORE.dfy OUT.dfy
"""
import re, sys
sys.path.insert(0, __import__('os').path.dirname(__file__))
from s4_check import read_export

TYPES = {}

def dterm(e):
    """The export tree as a Dafny term of datatype MExp."""
    k = e[0]
    if k == 'Var': return 'MVar("%s")' % e[1]
    if k == 'Int': return 'MLit(IntL(%d))' % e[1]
    if k == 'Str': return 'MLit(StrL([%s]))' % ', '.join(str(ord(c)) for c in e[1])
    if k == 'Bool': return 'MLit(BoolL(%s))' % ('true' if e[1] else 'false')
    if k == 'Not': return 'MUnOp(Not, %s)' % dterm(e[1])
    return 'MBinOp(%s, %s, %s)' % (k, dterm(e[1]), dterm(e[2]))

def typ(e):
    k = e[0]
    if k == 'Var': return TYPES[e[1]]
    if k == 'Int': return 'int'
    if k == 'Str': return 'string'
    return 'bool'

SYM = {'Eq': '==', 'Neq': '!=', 'Le': '<=', 'Lt': '<', 'Ge': '>=', 'And': '&&', 'Or': '||', 'Imp': '==>'}

def native(e):
    """The Dafny-native reading of a node (fully parenthesised)."""
    k = e[0]
    if k == 'Var': return e[1]
    if k == 'Int': return str(e[1])
    if k == 'Str': return '"%s"' % e[1]
    if k == 'Bool': return 'true' if e[1] else 'false'
    if k == 'Not': return '(!%s)' % native(e[1])
    if k == 'Eq' and typ(e[1]) == 'bool': return '(%s <==> %s)' % (native(e[1]), native(e[2]))
    return '(%s %s %s)' % (native(e[1]), SYM[k], native(e[2]))

def value_of(e):
    t = typ(e)
    if t == 'bool': return 'BoolV(%s)' % native(e)
    if t == 'int': return 'IntV(%s)' % native(e)
    return 'StrV(B(%s))' % native(e)

def steps(e, out, seen):
    """One proof step per node. Inner nodes use the generic step lemmas (no deep unfolding)."""
    for c in e[1:]:
        if isinstance(c, tuple): steps(c, out, seen)
    key = dterm(e)
    if key in seen: return
    seen.add(key)
    k = e[0]
    if k in ('Var', 'Int', 'Str', 'Bool'):
        out.append('    assert MEval(%s, env) == Rval(%s);' % (key, value_of(e)))
        return
    if k == 'Not':
        out.append('    NotStep(%s, env, %s);' % (dterm(e[1]), native(e[1])))
    elif k in ('And', 'Or', 'Imp'):
        out.append('    LogicStep(%s, %s, %s, env, %s, %s);' % (k, dterm(e[1]), dterm(e[2]), native(e[1]), native(e[2])))
    elif k in ('Eq', 'Neq'):
        out.append('    EqStep(%s, %s, %s, env, %s, %s);' % (k, dterm(e[1]), dterm(e[2]), value_of(e[1]), value_of(e[2])))
        if typ(e[1]) == 'string':
            out.append('    BInj(%s, %s);' % (native(e[1]), native(e[2])))
    elif k in ('Le', 'Lt', 'Ge'):
        out.append('    IntStep(%s, %s, %s, env, %s, %s);' % (k, dterm(e[1]), dterm(e[2]), native(e[1]), native(e[2])))
    else:
        raise ValueError(k)
    out.append('    assert MEval(%s, env) == Rval(%s);' % (key, value_of(e)))

def main(sexp_path, dfy_path, out_path):
    m = read_export(open(sexp_path).read())
    for n, t in m['ins'] + m['outs']: TYPES[n] = t
    src = open(dfy_path).read()
    # The three ensures clauses, copied byte for byte from the source text.
    spec = src[src.index('modifies {}') + len('modifies {}'):src.index('\n  {\n')]
    clauses = [c.strip() for c in spec.split('ensures ')[1:]]
    assert len(clauses) == 3 == len(m['ensures'])
    params = ', '.join('%s: %s' % (n, t) for n, t in m['ins'] + m['outs'])
    args = ', '.join(n for n, _ in m['ins'] + m['outs'])
    strs = [n for n, t in m['ins'] + m['outs'] if t == 'string']
    req = ' && '.join('Bytes(%s)' % s for s in strs)
    envs = ', '.join('"%s" := %s' % (n, {'string': 'StrV(B(%s))', 'int': 'IntV(%s)', 'bool': 'BoolV(%s)'}[t] % n)
                     for n, t in m['ins'] + m['outs'])
    lits = sorted({x[1] for e in m['ensures'] for x in walk(e) if x[0] == 'Str'})
    o = [HEADER]
    o.append('  predicate Bytes(s: string) { forall i | 0 <= i < |s| :: s[i] as int < 256 }')
    o.append('  function Env(%s): map<string, MValue>\n  {\n    map[%s]\n  }\n' % (params, envs))
    o.append('  lemma Literals()')
    for s in lits:
        o.append('    ensures Bytes("%s") && B("%s") == [%s]' % (s, s, ', '.join(str(ord(c)) for c in s)))
    o.append('  {')
    for s in lits:
        o.append('    assert |B("%s")| == %d;' % (s, len(s)))
    o.append('  }\n')
    for k, (tree, clause) in enumerate(zip(m['ensures'], clauses)):
        o.append('  // Clause %d, copied from the source text:\n  //   %s' % (k + 1, ' '.join(clause.split())))
        o.append('  const Tree%d: MExp := %s\n' % (k + 1, dterm(tree)))
        o.append('  predicate Source%d(%s)\n  {\n    %s\n  }\n' % (k + 1, params, clause))
        o.append('  lemma {:isolate_assertions} Agree%d(%s)\n    requires %s\n    ensures MEval(Tree%d, Env(%s)) == Rval(BoolV(Source%d(%s)))\n  {'
                 % (k + 1, params, req, k + 1, args, k + 1, args))
        o.append('    var env := Env(%s);\n    Literals();' % args)
        body = []; steps(tree, body, set()); o.extend(body)
        o.append('  }\n')
    o.append('}')
    open(out_path, 'w').write('\n'.join(o) + '\n')

def walk(e):
    yield e
    for c in e[1:]:
        if isinstance(c, tuple): yield from walk(c)

HEADER = '''// Y12 DRAFT (M1-B, link S7). Scratch file. NOT approved. NOT HOL. A proof about a MIRROR of HOL.
// Generated by gen_mirror.py from the export S-expression and the FlatCore.dfy source text.
module HolMirror {
  // ---- mirror of dafny_semanticPrimitivesScript.sml:20-27 (value; ArrV omitted: not in the fragment)
  // HOL mlstring = implode (char list), HOL char = 0..255; mirrored as seq<int>.
  datatype MValue = IntV(i: int) | BoolV(b: bool) | StrV(s: seq<int>)
  datatype Opt<T> = NONE | SOME(v: T)
  datatype Res = Rval(v: MValue) | Rfail     // Rerr Rfail; Rtimeout cannot arise for these cases
  datatype UnOp = Not
  datatype BinOp = Lt | Le | Ge | Eq | Neq | Sub | Add | Mul | And | Or | Imp | Div | Mod
  datatype Lit = BoolL(b: bool) | IntL(i: int) | StrL(s: seq<int>)
  datatype MExp = MLit(l: Lit) | MVar(n: string) | MUnOp(u: UnOp, e: MExp) | MBinOp(op: BinOp, e0: MExp, e1: MExp)
  datatype ScRes = Done(v: MValue) | Continue | Abort

  // ---- mirror of do_sc_def, dafny_semanticPrimitivesScript.sml:197-211
  function DoSc(op: BinOp, v: MValue): ScRes {
    match op
    case And => if v == BoolV(false) then Done(v) else if v == BoolV(true) then Continue else Abort
    case Or  => if v == BoolV(true) then Done(v) else if v == BoolV(false) then Continue else Abort
    case Imp => if v == BoolV(false) then Done(BoolV(true)) else if v == BoolV(true) then Continue else Abort
    case _ => Continue
  }
  // ---- mirror of do_uop_def, :213-215
  function DoUop(u: UnOp, v: MValue): Opt<MValue> {
    match v case BoolV(b) => SOME(BoolV(!b)) case _ => NONE
  }
  // ---- mirror of value_same_type_def, :217-223 (ArrV case omitted)
  predicate SameType(a: MValue, b: MValue) {
    (a.IntV? && b.IntV?) || (a.BoolV? && b.BoolV?) || (a.StrV? && b.StrV?)
  }
  // ---- mirror of do_bop_def, :233-284. Div and Mod (ediv/emod) are NOT mirrored: not in the fragment.
  function DoBop(op: BinOp, a: MValue, b: MValue): Opt<MValue> {
    match op
    case Eq  => if SameType(a, b) then SOME(BoolV(a == b)) else NONE
    case Neq => if SameType(a, b) then SOME(BoolV(a != b)) else NONE
    case And => if a.BoolV? && b.BoolV? then SOME(BoolV(a.b && b.b)) else NONE
    case Imp => if a.BoolV? && b.BoolV? then SOME(BoolV(a.b ==> b.b)) else NONE
    case Or  => if a.BoolV? && b.BoolV? then SOME(BoolV(a.b || b.b)) else NONE
    case Lt  => if a.IntV? && b.IntV? then SOME(BoolV(a.i < b.i)) else NONE
    case Le  => if a.IntV? && b.IntV? then SOME(BoolV(a.i <= b.i)) else NONE
    case Ge  => if a.IntV? && b.IntV? then SOME(BoolV(a.i >= b.i)) else NONE
    case Sub => if a.IntV? && b.IntV? then SOME(IntV(a.i - b.i)) else NONE
    case Add => if a.IntV? && b.IntV? then SOME(IntV(a.i + b.i)) else NONE
    case Mul => if a.IntV? && b.IntV? then SOME(IntV(a.i * b.i)) else NONE
    case Div => NONE   // NOT mirrored
    case Mod => NONE   // NOT mirrored
  }
  // ---- mirror of lit_to_val_def, :286-290
  function LitToVal(l: Lit): MValue {
    match l case IntL(i) => IntV(i) case BoolL(b) => BoolV(b) case StrL(s) => StrV(s)
  }
  // ---- mirror of evaluate_exp, dafny_evaluateScript.sml:36-68 (Lit, Var, UnOp, BinOp only).
  // read_local (:185-190) on locals that hold SOME v for every bound name is mirrored by a map.
  function MEval(e: MExp, env: map<string, MValue>): Res
    decreases e
  {
    match e
    case MLit(l) => Rval(LitToVal(l))
    case MVar(n) => if n in env then Rval(env[n]) else Rfail
    case MUnOp(u, a) =>
      (match MEval(a, env)
       case Rfail => Rfail
       case Rval(v) => (match DoUop(u, v) case NONE => Rfail case SOME(r) => Rval(r)))
    case MBinOp(op, a, b) =>
      (match MEval(a, env)
       case Rfail => Rfail
       case Rval(v0) =>
         (match DoSc(op, v0)
          case Abort => Rfail
          case Done(v) => Rval(v)
          case Continue =>
            (match MEval(b, env)
             case Rfail => Rfail
             case Rval(v1) => (match DoBop(op, v0, v1) case NONE => Rfail case SOME(r) => Rval(r)))))
  }

  // ---- generic one-step lemmas about the mirror (each is proved from the definition of MEval)
  lemma NotStep(a: MExp, env: map<string, MValue>, x: bool)
    requires MEval(a, env) == Rval(BoolV(x))
    ensures MEval(MUnOp(Not, a), env) == Rval(BoolV(!x))
  {}
  lemma LogicStep(op: BinOp, a: MExp, b: MExp, env: map<string, MValue>, x: bool, y: bool)
    requires op == And || op == Or || op == Imp
    requires MEval(a, env) == Rval(BoolV(x)) && MEval(b, env) == Rval(BoolV(y))
    ensures MEval(MBinOp(op, a, b), env) == Rval(BoolV(if op == And then x && y else if op == Or then x || y else x ==> y))
  {}
  lemma EqStep(op: BinOp, a: MExp, b: MExp, env: map<string, MValue>, va: MValue, vb: MValue)
    requires op == Eq || op == Neq
    requires MEval(a, env) == Rval(va) && MEval(b, env) == Rval(vb) && SameType(va, vb)
    ensures MEval(MBinOp(op, a, b), env) == Rval(BoolV(if op == Eq then va == vb else va != vb))
  {}
  lemma IntStep(op: BinOp, a: MExp, b: MExp, env: map<string, MValue>, x: int, y: int)
    requires op == Le || op == Lt || op == Ge
    requires MEval(a, env) == Rval(IntV(x)) && MEval(b, env) == Rval(IntV(y))
    ensures MEval(MBinOp(op, a, b), env) == Rval(BoolV(if op == Le then x <= y else if op == Lt then x < y else x >= y))
  {}

  // ---- the value relation R for strings: a Dafny string whose characters are all below 256
  function B(s: string): seq<int> { seq(|s|, i requires 0 <= i < |s| => s[i] as int) }
  lemma BInj(s: string, t: string)
    ensures B(s) == B(t) <==> s == t
  {
    if B(s) == B(t) {
      assert |s| == |t|;
      forall i | 0 <= i < |s| ensures s[i] == t[i] { assert B(s)[i] == B(t)[i]; }
    }
  }
'''

if __name__ == '__main__':
    main(*sys.argv[1:4])

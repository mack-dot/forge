# TEST OF A MIRROR: the mirror reproduces the stored HOL unit tests test_lex / test_parse (mlsexpScript.sml 170-224).
import sys, importlib.util
spec = importlib.util.spec_from_file_location("m", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
S = m.SYMBOL; O, C = m.OPEN, m.CLOSE
ok = []
r = m.lex(" 1 2   3 "); ok.append(isinstance(r, m.INR) and r.v == ([S("1")], " 2   3 "))
r = m.lex("\"\n \" 2"); ok.append(isinstance(r, m.INR) and r.v == ([S("\n ")], " 2"))
r = m.lex(" (1 2) 3 "); ok.append(isinstance(r, m.INR) and r.v == ([C, S("2"), S("1"), O], " 3 "))
r = m.lex(" (1 2) ) "); ok.append(isinstance(r, m.INR) and r.v == ([C, S("2"), S("1"), O], " ) "))
r = m.lex(" (1 2    "); ok.append(isinstance(r, m.INL) and r.v[1] == "")
r = m.lex(" ) (1 2) "); ok.append(isinstance(r, m.INL) and r.v[1] == " (1 2) ")
r = m.parse(" 1 2 3 "); ok.append(isinstance(r, m.INR) and r.v == (('Atom', "1"), " 2 3 "))
r = m.parse("(1 2 3)"); ok.append(isinstance(r, m.INR) and r.v == (('Expr', [('Atom', "1"), ('Atom', "2"), ('Atom', "3")]), ""))
r = m.parse("(()) ()"); ok.append(isinstance(r, m.INR) and r.v == (('Expr', [('Expr', [])]), " ()"))
r = m.parse("(c r 100 60 True True True 40 duplicate_charge) (evil)"); ok.append(isinstance(r, m.INR) and r.v[1] == " (evil)")
print("selfcheck", ok); sys.exit(0 if all(ok) else 1)

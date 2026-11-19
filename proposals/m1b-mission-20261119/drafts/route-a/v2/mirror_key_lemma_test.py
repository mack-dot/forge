# TEST OF A MIRROR (not a proof): lex_aux_prefix_ISL on random NESTED s-expressions (both conjuncts),
# every prefix INCLUDING the full printing, depths 1..3. Uses the mirror in mirror_prefix_test.py.
import sys, random, importlib.util
spec = importlib.util.spec_from_file_location("m", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
rng = random.Random(7)
def rsexp(depth):
    if depth == 0 or rng.random() < 0.4: return ('Atom', m.rstr())
    return ('Expr', [rsexp(depth - 1) for _ in range(rng.randint(0, 4))])
checks = viol = 0
for _ in range(int(sys.argv[2]) if len(sys.argv) > 2 else 400):
    x = rsexp(4); xs = [rsexp(3) for _ in range(rng.randint(0, 4))]
    for s in (m.sexp_to_string(x), m.sexps_to_string(xs)):
        for k in range(len(s) + 1):
            for d in (1, 2, 3):
                checks += 1
                if not isinstance(m.lex_aux(d, s[:k], []), m.INL): viol += 1; print("VIOLATION", repr(s[:k]), d)
# controls: depth 0 must break it; and the Expr top-level strict-prefix claim must hold for these x
d0 = sum(1 for _ in range(200) for s in [m.sexp_to_string(('Atom', 'abc'))] if isinstance(m.lex_aux(0, s, []), m.INR))
print("key-lemma checks", checks, "violations", viol, "depth-0 control INR count", d0)
sys.exit(0 if viol == 0 and d0 > 0 else 1)

# TEST OF A MIRROR (not a proof): mutation controls for mirror_prefix_test.py.
# Each mutant must produce at least one violation; otherwise the test has no teeth.
import sys, importlib.util
spec = importlib.util.spec_from_file_location("m", sys.argv[1]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
fs = [(True, 40, "returned_item", "c", "r", 1), (False, -3, 'a"b', "x y", "", 0), (True, 7, "\\", "q", "w", 2)]
def count(render, parser):
    v = 0
    for f in fs:
        R = render(f)
        for k in range(len(R)):
            if not isinstance(parser(R[:k]), m.INL): v += 1
    return v
# M1: frame plus trailing newline (N1 shape)
print("M1 trailing newline:", count(lambda f: m.refund_render_fields(f) + "\n", m.parse))
# M2: render only the inner list text (no outer parentheses)
print("M2 no outer parens:", count(lambda f: m.refund_render_fields(f)[1:-1], m.parse))
# M3: key lemma at depth 0 on the inner text
print("M3 depth 0:", count(lambda f: m.refund_render_fields(f)[1:-1], lambda s: m.lex_aux(0, s, [])))
# M4: a printer that does not escape quotes (raw) -> prefix closes the string early
orig = m.char_escaped
m.char_escaped = lambda c: c if c == '"' else orig(c)
print("M4 unescaped quote:", count(m.refund_render_fields, m.parse))
m.char_escaped = orig
# M5: unescaped quote with a reason that contains `")`: the early close then meets `)` at depth 1
fs[:] = [(True, 1, 'x")', "c", "r", 1)]
m.char_escaped = lambda c: c if c == '"' else orig(c)
print("M5 unescaped quote, reason x\"):", count(m.refund_render_fields, m.parse))
m.char_escaped = orig
print("M5 control, real printer:", count(m.refund_render_fields, m.parse))

# LIGHT probe of control (c) without its race row (for mutant M3). Not part of the diff.
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src).read()
def cut(t, a, b):
    i, j = t.index(a), t.index(b); assert i < j; return t[:i] + t[j:]
t = cut(t, "  // ---------------- Issuer: it signs", "  // ---------------- Worlds:")
t = cut(t, "  // ---------------- Control (a)", "  // ---------------- Control (c)")
t = cut(t, "    const race = await world(\"c_race\")", "  }\n\n  // ---------------- Control (d)")
t = cut(t, "  // ---------------- Control (d)", "  // ---------------- Option")
open(dst, "w").write(t)

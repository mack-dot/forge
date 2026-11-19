# Makes a LIGHT probe from a suite.ts: drops the issuer grid, controls a-d and the race rows x9/x10. Not part of the diff.
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src).read()
def cut(t, a, b):
    i, j = t.index(a), t.index(b)
    assert i < j
    return t[:i] + t[j:]
t = cut(t, "  // ---------------- Issuer: it signs", "  // ---------------- Worlds:")
t = cut(t, "  // ---------------- Control (a)", "  // ---------------- Dispatcher:")
t = cut(t, "    { // Review finding F2", "  }\n\n  { // Finding of the repair check: one ledger")
t = cut(t, "  { // Finding of the repair check: one ledger", "  // ---------------- Option")
open(dst, "w").write(t)

# h-minter2: LIGHT probe of suite.ts: drops the dispatcher section only (process races). Not part of the diff.
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src).read()
i, j = t.index("  // ---------------- Dispatcher:"), t.index("  // ---------------- Option")
open(dst, "w").write(t[:i] + t[j:])

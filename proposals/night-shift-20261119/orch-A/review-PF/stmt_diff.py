# Extract lemma statements and definitions from PF-000N.sml and compare (pure, read-only).
import re, sys, hashlib
D = "/Users/USER/forge/results/m1b-routeA-20261119/attempt-0001/"
def stmts(path):
    s = open(path).read()
    out = {}
    for m in re.finditer(r'thm\s+"([^"]+)"\s*\(fn \(\) =>\s*``(.*?)``\)', s, re.S):
        out[m.group(1)] = " ".join(m.group(2).split())
    for m in re.finditer(r'defn\s+"([^"]+)"\s*`(.*?)`;', s, re.S):
        out["DEF:" + m.group(1)] = " ".join(m.group(2).split())
    for m in re.finditer(r'(?:Define|new_definition)\s*\(?\s*(?:"([^"]+)"\s*,\s*)?`(.*?)`', s, re.S):
        out.setdefault("RAWDEF:" + (m.group(1) or m.group(2)[:20]), " ".join(m.group(2).split()))
    return out
V = {}
for n in ["PF-0001", "PF-0002", "PF-0003", "PF-0004"]:
    V[n] = stmts(D + n + ".sml"); print(n, hashlib.sha256(open(D+n+".sml","rb").read()).hexdigest()[:16], len(V[n]), "statements")
names = ["PF-0001", "PF-0002", "PF-0003", "PF-0004"]
for a, b in zip(names, names[1:]):
    A, B = V[a], V[b]
    print(a, "->", b, "added:", sorted(set(B) - set(A)), "removed:", sorted(set(A) - set(B)))
    for k in sorted(set(A) & set(B)):
        if A[k] != B[k]: print("  CHANGED", k, "\n   old:", A[k], "\n   new:", B[k])
for k in sorted(V["PF-0004"]): print("PF-0004", k)

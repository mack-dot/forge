# summarize.py <tag>...: per tag, the regress FAIL lines that are NOT in the v6 baseline (X6-Z1), the regress exit,
# and the spec-conformance properties beyond the v6 baseline (P5-SILENT only), with the spec exit.
import json, re, sys, os
EV = os.path.dirname(os.path.abspath(__file__))
def reg(tag):
    L = open(f"{EV}/logs/{tag}.regress.log").read().splitlines()
    fails = [l.split(":")[0].split()[1] for l in L if l.startswith("FAIL ")]
    lines = [l for l in L if re.match(r"^(PASS|FAIL|KNOWN-LIMIT) ", l)]
    ex = [l for l in L if l.startswith("exit ")][-1]
    return [f for f in fails if f != "X6-Z1-zero-row-deleted-recommitted"], len(lines), ex.split()[1]
def spec(tag):
    j = None; ex = "?"
    for l in open(f"{EV}/logs/{tag}.spec.log"):
        if l.startswith("{"): j = json.loads(l)
        if l.startswith("exit "): ex = l.split()[1]
    if j is None: return None, ex, None
    v = {k: n for k, n in j["sequencesWithViolation"].items() if k != "P5-SILENT"}
    return v, ex, j
rows = []
for tag in sys.argv[1:]:
    rf, n, rex = reg(tag); sv, sex, j = spec(tag)
    rc = bool(rf); sc = (sv is None) or bool(sv)
    verdict = "BLIND(both)" if not rc and not sc else ("regress-only" if rc and not sc else ("spec-only" if sc and not rc else "both"))
    print(f"{tag:26s} regress: newFAIL={','.join(rf) or '-'} lines={n} exit={rex} | spec: {('NO JSON' if sv is None else (json.dumps(sv) if sv else '-'))} exit={sex} | {verdict}")

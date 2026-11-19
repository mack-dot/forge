import sys, re
d = sys.argv[1]; guard = open(sys.argv[2]).read()
pat = re.compile(r"Timeout\.apply \(Time\.fromSeconds \(Int\.toLarge ([A-Za-z_]+)\)\) \(fn \(\) => ([^()]*?(?:\([^()]*\))?[^()]*?)\) \(\)")
for name, hdr, thy in [('R6rx-0003.sml', 'R6rx-0003.sml (worker W-pre, preflight round13). EXPLORATION, NOT RUN. = round12/R6rx-0002.sml with only: this comment,\n   the guard block after trunc (guarded_apply replaces Timeout.apply in run_ts, explore_head, tlim), the theory name\n   forge_refundR6RExplore3, R6RDIR = preflight/round13/. Every tactic and the guard are UNCHECKED. Round 12 header follows. *)\n', True),
                       ('R6r-0003.sml', 'R6r-0003.sml (worker W-pre, preflight round13). PROOF, NOT RUN. = round12/R6r-0002.sml with only: this comment, the\n   guard block after trunc (guarded_apply replaces Timeout.apply in tlim), R6RDIR = preflight/round13/. Theory\n   forge_refundR6Read unchanged. Every tactic and the guard are UNCHECKED. Round 12 header follows. *)\n', False)]:
    p = d + '/' + name; s = open(p).read()
    s = '(* ' + hdr + s
    m = re.search(r"^fun trunc .*\n", s, re.M); s = s[:m.end()] + guard + s[m.end():]
    s, k = pat.subn(lambda m: "guarded_apply %s (fn () => %s)" % (m.group(1), m.group(2)), s)
    print(name, 'replaced', k, 'remaining Timeout.apply', s.count('Timeout.apply ('))
    s = s.replace('/orch-A/r6/round12/"', '/orch-A/r6/preflight/round13/"')
    if thy: s = s.replace('new_theory "forge_refundR6RExplore2"', 'new_theory "forge_refundR6RExplore3"')
    open(p, 'w').write(s)

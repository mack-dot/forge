# A2 prefix lemma (worker report, condensed by Orchestrator A; HOL NOT RUN; all tactics UNCHECKED)
- `prefix_lemma_v3.sml` (820de134…): tactic-only repairs T1–T8 of v2 (T1: main chain branch q=[] would probably fail);
  no v2 statement changed; two theorems added: `every_isPREFIX`, `refund_render_fields_prefix_code`
  (`explode (render g) ≼ explode (render f) ⇒ g = f`).
- Mirror attack `a2_attack.py` exit 0: 132,450 strict prefixes of 2,358 field tuples, 0 accepted. TESTED-UNPROVED.
- Finding S4: `refund_strict_parse` is NOT the consumer's parser (`frame.strict_parse` is stricter; 37,538 mutants are
  accepted by the HOL parser only; every consumer-accepted mutant is HOL-accepted with equal values).
- Ready: `FORGE_CPU_SECONDS=600 ./go-routeA.sh PF-0001 PF-0001.sml deps-L1.txt` in `results/m1b-routeA-20261119/attempt-0001`.
  Pass: exit 0; EXACT_COMPLETE; 23 CHECKED; 3 DEFINITION; 5 CONTROL_OK; 4 CLOSURE_AXIOM. Worker's own pass estimate: 25 %.

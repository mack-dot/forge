#!/usr/bin/env python3
"""Kind-inference probes (task 2), r-subset3b."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen import write
K = 'kind'
write(K, 'K01-empty-display-chain-plus', pre='    var a1 := [];\n    var a2 := a1;\n    var a3 := a2 + [1];', fact='|a3| == 1')
write(K, 'K02-tuple-component-plus', pre='    var t := (1, "a");\n    var u := t.1 + t.1;', fact='|u| == 2')
write(K, 'K03-match-binder-plus', pre='    var u := match response case Candidate(a, r) => r + r case _ => "";', fact='true')
write(K, 'K04-if-shapes', pre='    var x := if response.Candidate? then [] else [1, 2, 3];', fact='|x| <= 3')
write(K, 'K05-helper-field', helpers='  function Mk(): Decision { Authorized(1, "x") }', pre='    var y := Mk().amount + 1;', fact='y == 2')
write(K, 'K06-as-int', pre='    var y := |context.chargeId| as int;', fact='y >= 0')
write(K, 'K07-card-plus', pre='    var y := |context.chargeId| + |context.chargeId|;', fact='y >= 0')
write(K, 'K08-string-fn-plus', helpers='  function S(x: int): string { "ab" }', pre='    var y := S(1) + S(1);', fact='|y| == 4')
write(K, 'K09-tuple-nest-4', helpers='  function Two(x: int): (int, int) { (x, x) }',
      pre='    var a1 := Two(response.amount);\n    var a2 := (a1, a1);\n    var a3 := (a2, a2);\n    var a4 := (a3, a3);', fact='a4 == a4 && a1.1 == response.amount')
write(K, 'K10-tuple-nest-5', pre='    var a1 := (1, 1);\n    var a2 := (a1, a1);\n    var a3 := (a2, a2);\n    var a4 := (a3, a3);\n    var a5 := (a4, a4);', fact='true')
write(K, 'K11-seq-of-seq-share', pre='    var a1 := [response.amount, response.amount];\n    var a2 := [a1, a1];\n    var a3 := [a2, a2];\n    var a4 := [a3, a3];', fact='a1 in a2')
write(K, 'K12-plan-eq-input', pre='    var p := [Intent(context.chargeId, context.requestId, response.amount, response.reason)];', fact='|p| == 1')
write(K, 'K13-var-typed-seq-char', pre='    var s: seq<char> := context.chargeId;', fact="s == context.chargeId")
write(K, 'K14-set-minus', pre='    var s1 := {1};\n    var s2 := s1 - s1;', fact='|s2| == 0')
write(K, 'K15-set-times', pre='    var s1 := {1};\n    var s2 := s1 * s1;', fact='|s2| == 1')
write(K, 'K16-string-index', pre='    var c := context.chargeId[0];', fact='true')
write(K, 'K17-tuple-from-match-binder', pre='    var t := (context.chargeId, 1);\n    var u := match t case (s, n) => n + n;', fact='u == 2')
write(K, 'K18-out-param-tree', helpers='  method P(x: int) returns (r: seq<(int, int)>) { r := [(x, x), (x, x), (x, x), (x, x), (x, x), (x, x), (x, x), (x, x), (x, x), (x, x)]; }',
      pre='    var q := P(1);\n    var q2 := [q, q];', fact='true')

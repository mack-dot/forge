# JS checker verdicts (MACHINE: results/check-*.jsonl; js_bound_check.cjs; light single Node runs)

Inputs: `dafny translate js --no-verify` outputs in js/ (this task, through dafny_locked.sh) and reused builds in
js-reuse/ (r-subset2, e-subset3, r-subset3). Columns 4-8: verdict of each mutant of the checker.

## Unsafe (must be refused)

| file | verdict | code / detail | no-loop | no-recursion | no-load | no-shape | no-cost |
|---|---|---|---|---|---|---|---|
| E06-stack-overflow-keyed | REFUSE | RECURSION recursion through DeepM not bounded within 64 unfoldings | refuse | ACCEPT | refuse | refuse | refuse |
| E07-oom-keyed | REFUSE | LOOP sequence comprehension length not bounded by 4096 | ACCEPT | refuse | refuse | refuse | refuse |
| E08-time-keyed | REFUSE | LOOP loop exit not established within 4096 unfoldings: while ((_1 | ACCEPT | refuse | refuse | refuse | refuse |
| H01b-such-that-modulus-hang | REFUSE | STATEMENT ForOfStatement is outside the admitted statements: for (cons | refuse | refuse | refuse | refuse | refuse |
| H02-exponential-recursion-hang | REFUSE | RECURSION recursion through Slow not bounded within 64 unfoldings | refuse | ACCEPT | refuse | refuse | refuse |
| H03-seq-comprehension-alloc | REFUSE | LOOP sequence comprehension length not bounded by 4096 | ACCEPT | refuse | refuse | refuse | refuse |
| H04-seq-length-2pow32-throws | REFUSE | LOOP sequence comprehension length not bounded by 4096 | ACCEPT | refuse | refuse | refuse | refuse |
| Z24-expect-halt-amount-1000 | REFUSE | HALT `throw` in compiled code (a run-time halt): throw new _dafny | refuse | refuse | refuse | refuse | refuse |
| A01-dag-equality-2x40 | REFUSE | SIZE value bound 0*N + 49151 over the caps at _dafny.Seq.of((((_0 | refuse | refuse | refuse | ACCEPT | refuse |
| A01m-dag-equality-2x22-measure | REFUSE | SIZE value bound 0*N + 49151 over the caps at _dafny.Seq.of((((_0 | refuse | refuse | refuse | ACCEPT | refuse |
| A03-extra-module-require | REFUSE | NAME module name require is a JavaScript, runtime or global name | refuse | refuse | refuse | refuse | refuse |
| A03-extra-module-BigNumber | REFUSE | NAME module name BigNumber is a JavaScript, runtime or global nam | refuse | refuse | refuse | refuse | refuse |
| A08-param-shadows-const-display | REFUSE | LOOP loop exit not established within 4096 unfoldings: for (let _ | ACCEPT | refuse | refuse | refuse | refuse |
| A09-local-shadows-const-display | REFUSE | LOOP loop exit not established within 4096 unfoldings: for (let _ | ACCEPT | refuse | refuse | refuse | refuse |
| A10-recursion-shadowed-const-display | REFUSE | LOOP loop exit not established within 4096 unfoldings: while (tru | ACCEPT | refuse | refuse | refuse | refuse |
| P03-js-proto-hasown | REFUSE | LOAD module does not load or export Assess(context, response): Sy | refuse | refuse | ACCEPT | refuse | refuse |
| A05-hex-multiplier-loop | REFUSE | SIZE value bound 0*N + 32833 over the caps at (_0_x).multipliedBy | ACCEPT | refuse | refuse | refuse | refuse |
| HV06-call-tower-exponential | REFUSE | COST more than 1000000 abstract steps for one Assess call | refuse | refuse | refuse | refuse | ACCEPT |
| HV07-repeated-squaring | REFUSE | SIZE value bound 32*N + 2048 over the caps at (_4_x4).multipliedB | refuse | refuse | refuse | refuse | refuse |
| HV08-string-doubling | REFUSE | SIZE value bound 32*N + 2048 over the caps at _dafny.Seq.Concat(_ | refuse | refuse | refuse | ACCEPT | refuse |
| HV10-tuple-dag-equality | NOT RUN (no translation) | |  |  |  |  |  |
| Y06-helper-fanout-2x12 | NOT RUN (no translation) | |  |  |  |  |  |
| Y46-seq-concat-doubling | REFUSE | SIZE value bound 32*N + 2080 over the caps at _dafny.Seq.Concat(_ | refuse | refuse | refuse | ACCEPT | refuse |

## Unsafe GHOST axioms (C-GATE-05): the JS tier cannot see ghost code; owner = Dafny verify (non-zero exit) and audit (red-team logs orch-C/c13-gate-js/logs: A01 verify exit 2, audit exit 2; A02 verify exit 2)

| file | verdict | code / detail | no-loop | no-recursion | no-load | no-shape | no-cost |
|---|---|---|---|---|---|---|---|
| A01-bodiless-lemma-brace-end | NOT RUN (no translation) | |  |  |  |  |  |
| A02-bodiless-ghost-pred-brace-end | NOT RUN (no translation) | |  |  |  |  |  |
| A13-ghost-method-bodiless-brace | NOT RUN (no translation) | |  |  |  |  |  |
| A14-lemma-ensures-set-literal-end | NOT RUN (no translation) | |  |  |  |  |  |
| A15-forall-ensures-in-lemma | NOT RUN (no translation) | |  |  |  |  |  |
| A16-induction-false-lemma | NOT RUN (no translation) | |  |  |  |  |  |
| A17-isolate-on-bodiless | NOT RUN (no translation) | |  |  |  |  |  |

## Correct, refused by rule 3 (21)

| file | verdict | code / detail | no-loop | no-recursion | no-load | no-shape | no-cost |
|---|---|---|---|---|---|---|---|
| C04-local-datatype-verdict | ACCEPT | BOUNDED steps<=167 size<=6*N+388 cost<=7351+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C05-loop-over-local-reason-list | ACCEPT | BOUNDED steps<=244 size<=6*N+388 cost<=1650+17*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C06-reason-index-loop-early-exit | ACCEPT | BOUNDED steps<=294 size<=6*N+388 cost<=1968+17*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C08-label-assert | ACCEPT | BOUNDED steps<=158 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C16-reason-string-concat-log | ACCEPT | BOUNDED steps<=174 size<=6*N+388 cost<=7421+69*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C18-for-range-over-local-list | ACCEPT | BOUNDED steps<=228 size<=6*N+388 cost<=1650+17*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C19-map-reason-table | ACCEPT | BOUNDED steps<=159 size<=6*N+388 cost<=4930+74*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C20-loop-with-break | ACCEPT | BOUNDED steps<=255 size<=6*N+388 cost<=1512+17*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| A11-abstract-trap-dead | ACCEPT | BOUNDED steps<=158 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C1-table | ACCEPT | BOUNDED steps<=274 size<=6*N+388 cost<=1968+17*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C2-recursion | ACCEPT | BOUNDED steps<=305 size<=6*N+388 cost<=7796+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C4-arith | ACCEPT | BOUNDED steps<=214 size<=6*N+394 cost<=7662+71*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C7-loop-plan | ACCEPT | BOUNDED steps<=187 size<=6*N+389 cost<=7622+72*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| N01-while-literal-table | ACCEPT | BOUNDED steps<=242 size<=6*N+388 cost<=1512+17*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| N02-for-const-display-table | ACCEPT | BOUNDED steps<=240 size<=6*N+388 cost<=1809+17*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| N03-for-bounded-local-plan | ACCEPT | BOUNDED steps<=183 size<=6*N+389 cost<=7622+72*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| N04-flag-product | ACCEPT | BOUNDED steps<=184 size<=6*N+388 cost<=7369+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| N05-recursion-over-display | ACCEPT | BOUNDED steps<=255 size<=6*N+388 cost<=7706+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| N06-extra-ghost-module | ACCEPT | BOUNDED steps<=158 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| N08-input-field-product | ACCEPT | BOUNDED steps<=174 size<=8*N+520 cost<=12089+202*N+1*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| N09-nested-literal-loops | ACCEPT | BOUNDED steps<=311 size<=6*N+388 cost<=7485+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |

## Reviewer files F01-F10 (correct, verified)

| file | verdict | code / detail | no-loop | no-recursion | no-load | no-shape | no-cost |
|---|---|---|---|---|---|---|---|
| F01-match-no-braces | ACCEPT | BOUNDED steps<=171 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| F02-set-in-guard | ACCEPT | BOUNDED steps<=149 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| F03-typed-set-const | ACCEPT | BOUNDED steps<=152 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| F04-seq-param-helper | ACCEPT | BOUNDED steps<=162 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| F05-calc-in-body | ACCEPT | BOUNDED steps<=158 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| F06-named-result | ACCEPT | BOUNDED steps<=167 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| F07-local-name-length | ACCEPT | BOUNDED steps<=164 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| F08-seq-append-one | ACCEPT | BOUNDED steps<=160 size<=6*N+389 cost<=7608+72*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| F09-let-expression | ACCEPT | BOUNDED steps<=169 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| F10-tuple-nested-select | ACCEPT | BOUNDED steps<=200 size<=6*N+388 cost<=7544+71*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |

## Correct, accepted by rule 3 (sample)

| file | verdict | code / detail | no-loop | no-recursion | no-load | no-shape | no-cost |
|---|---|---|---|---|---|---|---|
| Refund | ACCEPT | BOUNDED steps<=158 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C01-early-return | NOT RUN (no translation) | |  |  |  |  |  |
| C02-match-tuple | NOT RUN (no translation) | |  |  |  |  |  |
| C03-set-literal-reasons | NOT RUN (no translation) | |  |  |  |  |  |
| C07-tuple-destructure | NOT RUN (no translation) | |  |  |  |  |  |
| C13-match-expression-arms | NOT RUN (no translation) | |  |  |  |  |  |
| CV05-local-constants | NOT RUN (no translation) | |  |  |  |  |  |

## Review bypasses of the RULE-2 cost argument that this checker ADMITS with a stated bound (one Assess call measured: logs/drive_bounded.out, 0-29 ms)

| file | verdict | code / detail | no-loop | no-recursion | no-load | no-shape | no-cost |
|---|---|---|---|---|---|---|---|
| A04-seq-of-seq-growth | ACCEPT | BOUNDED steps<=13373 size<=6*N+1202 cost<=389926+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| A05b-hex-multiplier-loop-100 | ACCEPT | BOUNDED steps<=1569 size<=6*N+15201 cost<=115910165+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| A06-minus-doubling-loop | ACCEPT | BOUNDED steps<=10371 size<=6*N+1264 cost<=1220925+1868*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y48-method-out-tree-growth | ACCEPT | BOUNDED steps<=175 size<=6*N+388 cost<=7543+71*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |

## Other files with JavaScript (argued-bounded hostile, lexer probes, JS-name probes)

| file | verdict | code / detail | no-loop | no-recursion | no-load | no-shape | no-cost |
|---|---|---|---|---|---|---|---|
| A01s-dag-equality-2x12-small | ACCEPT | BOUNDED steps<=682 size<=6*N+12287 cost<=81113+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| A18-runtime-exhaustion | REFUSE | LOOP loop exit not established within 4096 unfoldings: while ((_0 | ACCEPT | refuse | refuse | refuse | refuse |
| A32-dead-main-decreases-star | REFUSE | SHAPE top-level statement is not a module: _dafny.HandleHaltExcept | refuse | refuse | refuse | refuse | refuse |
| A33-const-alloc-exhaustion | REFUSE | LOOP sequence comprehension length not bounded by 4096 | ACCEPT | refuse | refuse | refuse | refuse |
| A37-uncompilable-such-that | REFUSE | STATEMENT ForOfStatement is outside the admitted statements: for (cons | refuse | refuse | refuse | refuse | refuse |
| C02-int-match-stmt-no-default | ACCEPT | BOUNDED steps<=180 size<=6*N+388 cost<=7414+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C03-int-match-expr-no-default | ACCEPT | BOUNDED steps<=178 size<=6*N+388 cost<=7414+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C04-string-match-no-default | ACCEPT | BOUNDED steps<=173 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C09-div-by-named-zero | ACCEPT | BOUNDED steps<=166 size<=6*N+388 cost<=7358+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C19-member-named-amount | ACCEPT | BOUNDED steps<=165 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C20-member-toJSON | ACCEPT | BOUNDED steps<=165 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| C21-member-__defineGetter | ACCEPT | BOUNDED steps<=169 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| E02-array-oob | REFUSE | CALL unresolved call target Array | refuse | refuse | refuse | refuse | refuse |
| G01-reason-list-helper | ACCEPT | BOUNDED steps<=156 size<=6*N+388 cost<=4593+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| G02-let-expression-cap | ACCEPT | BOUNDED steps<=182 size<=6*N+388 cost<=7542+71*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| G03-reason-in-set-guard | ACCEPT | BOUNDED steps<=149 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| G04-intent-local-each-branch | ACCEPT | BOUNDED steps<=157 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| G05-min-helper-in-chain | ACCEPT | BOUNDED steps<=192 size<=6*N+388 cost<=7670+73*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| G06-early-return | ACCEPT | BOUNDED steps<=168 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| G07-decide-helper-method | ACCEPT | BOUNDED steps<=167 size<=8*N+518 cost<=7479+70*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| G08-ok-flag-in-two-branches | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| G09-percent-cap-const | ACCEPT | BOUNDED steps<=181 size<=6*N+388 cost<=8661+86*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| G10-valid-amount-predicate | ACCEPT | BOUNDED steps<=156 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| G11-digit-separator-cap | ACCEPT | BOUNDED steps<=179 size<=6*N+388 cost<=7836+69*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| H01-such-that-enumeration-hang | REFUSE | STATEMENT ForOfStatement is outside the admitted statements: for (cons | refuse | refuse | refuse | refuse | refuse |
| HV11-match-huge-literal-admissible-size | ACCEPT | BOUNDED steps<=2886 size<=6*N+388 cost<=13917+79*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| HV15-ghost-method-with-loop | ACCEPT | BOUNDED steps<=158 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| HV24-negation-doubling | ACCEPT | BOUNDED steps<=1976 size<=6*N+464 cost<=165641+669*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| HV25-tuple-of-helper-tuples | ACCEPT | BOUNDED steps<=192 size<=6*N+388 cost<=7703+73*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| L11-block-comment-with-slashes-cr | ACCEPT | BOUNDED steps<=158 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| L12-string-with-comment-close | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| L13-verbatim-doubled-quote | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| L14-char-dquote-and-escaped-quote | ACCEPT | BOUNDED steps<=164 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| MF12-match-flatten-k12 | ACCEPT | BOUNDED steps<=359 size<=12*N+769 cost<=8897+92*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| MF4-match-flatten-k4 | ACCEPT | BOUNDED steps<=231 size<=6*N+388 cost<=7865+76*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| MF8-match-flatten-k8 | ACCEPT | BOUNDED steps<=295 size<=8*N+513 cost<=8381+84*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| N01-prime-vs-k-member | ACCEPT | BOUNDED steps<=194 size<=6*N+388 cost<=7366+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| P01-js-locals | ACCEPT | BOUNDED steps<=176 size<=6*N+388 cost<=7358+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| P02-js-members | REFUSE | NAME member name valueOf | refuse | refuse | refuse | refuse | refuse |
| S01-string-nul-digit | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| S02-verbatim-backslash-end | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| S03-verbatim-unicode-escape | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| S04-verbatim-newline | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| S05-char-nul | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| S06-verbatim-cr | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| S07-verbatim-vt | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| S08-verbatim-dollar-brace | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| S09-verbatim-backslash-quote | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| X02-for-literal-bigint-multiplier | ACCEPT | BOUNDED steps<=880 size<=6*N+8448 cost<=35418503+8452*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| X06-loop-one-level-input-product | ACCEPT | BOUNDED steps<=1193 size<=6*N+388 cost<=279111+8260*N+64*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| X33-ls-comment-loop-text | ACCEPT | BOUNDED steps<=158 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| X38-bounded-local-in-display-append-loop | ACCEPT | BOUNDED steps<=636 size<=6*N+1137 cost<=18411+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y02-if-tower-40 | ACCEPT | BOUNDED steps<=761 size<=6*N+388 cost<=11029+108*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y03-match-nest-20 | ACCEPT | BOUNDED steps<=541 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y07-helper-fanout-2x3 | ACCEPT | BOUNDED steps<=1224 size<=6*N+388 cost<=64085+580*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y13-length-of-input | ACCEPT | BOUNDED steps<=178 size<=6*N+388 cost<=7553+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y14-string-compare-chain | ACCEPT | BOUNDED steps<=213 size<=6*N+388 cost<=7870+72*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y15-large-int-compare | ACCEPT | BOUNDED steps<=187 size<=6*N+388 cost<=7801+74*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y17-ghost-method-loop-huge | ACCEPT | BOUNDED steps<=175 size<=6*N+388 cost<=7441+69*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y24-addition-doubling-400 | ACCEPT | BOUNDED steps<=2570 size<=6*N+463 cost<=217315+867*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y25-literal-multiplier-chain-300 | ACCEPT | BOUNDED steps<=1970 size<=6*N+19499 cost<=192413642+19504*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y28-set-display-in-if-expression | ACCEPT | BOUNDED steps<=179 size<=6*N+388 cost<=8062+77*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y34-tuple-helper-equality | ACCEPT | BOUNDED steps<=192 size<=6*N+388 cost<=8121+80*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y42-long-literals-display | ACCEPT | BOUNDED steps<=190 size<=6*N+4017 cost<=272534+4085*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y42b-literals-display-16x64 | ACCEPT | BOUNDED steps<=190 size<=6*N+1041 cost<=76118+1109*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y45-if-statement-tower-30 | ACCEPT | BOUNDED steps<=553 size<=6*N+388 cost<=10109+98*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |
| Y50-assert-hides-statement | ACCEPT | BOUNDED steps<=161 size<=6*N+388 cost<=7349+68*N+0*N^2 | ACCEPT | ACCEPT | ACCEPT | ACCEPT | ACCEPT |

## Totals

- unsafe refused: 21 of 21 with JavaScript (of 23 named)
- refused-correct (rule 3 + F01-F10) now accepted: 31 of 31 with JavaScript
- accepted-correct sample still accepted: 1 of 1

- mutant no-loop admits unsafe: E07-oom-keyed, E08-time-keyed, H03-seq-comprehension-alloc, H04-seq-length-2pow32-throws, A08-param-shadows-const-display, A09-local-shadows-const-display, A10-recursion-shadowed-const-display, A05-hex-multiplier-loop
- mutant no-recursion admits unsafe: E06-stack-overflow-keyed, H02-exponential-recursion-hang
- mutant no-load admits unsafe: P03-js-proto-hasown
- mutant no-shape admits unsafe: A01-dag-equality-2x40, A01m-dag-equality-2x22-measure, HV08-string-doubling, Y46-seq-concat-doubling
- mutant no-cost admits unsafe: HV06-call-tower-exponential
- unsafe files the checker ADMITS: none

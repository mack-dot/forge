# Per-change tables (h-gate). Stages RUN: source scope (MACHINE) and JS check (MACHINE, translated files only).
Dafny verify, build and tests: NOT RUN (prepared: heavy/gate_jsbound.sh). For V0-V2 an "admitted" file still
goes to Dafny; the halting files verify (earlier runs), so V0-V2 admit them in the real gate.
Halting NOT RUN in V3 = A16-decreases-star: `dafny translate` exits 2 (resolution error), so the gate refuses it at verify.

## V0 pristine 985f5eaf

| set | admitted | refused (cause: count) | NOT RUN (no translation) |
|---|---|---|---|
| B correct (67) | 61 | SOURCE_SCOPE: exact approved refinement and sole incl: 3; SOURCE_SCOPE: only assertion-isolation attributes all: 3 | 0 |
| C correct (10 + G11) | 11 | - | 0 |
| halting (24; includes the seven) | 24 (UNSAFE ADMITTED by the stages run) | - | 0 |
| rule-2 review bypasses (23) | 20 (UNSAFE ADMITTED by the stages run) | SOURCE_SCOPE: exact approved refinement and sole incl: 1; SOURCE_SCOPE: only assertion-isolation attributes all: 2 | 0 |
| ghost axioms C-GATE-05 (7): NOT RUN here = `dafny translate` itself fails (exit 3 warnings x6, exit 2 x1; logs/A*.translate.7.log), so verify, build and audit refuse them | 6 (UNSAFE ADMITTED by the stages run) | SOURCE_SCOPE: only assertion-isolation attributes all: 1 | 0 |

## V1 + scope-minimal (diff i)

| set | admitted | refused (cause: count) | NOT RUN (no translation) |
|---|---|---|---|
| B correct (67) | 66 | SOURCE_SCOPE: only assertion-isolation attributes all: 1 | 0 |
| C correct (10 + G11) | 11 | - | 0 |
| halting (24; includes the seven) | 24 (UNSAFE ADMITTED by the stages run) | - | 0 |
| rule-2 review bypasses (23) | 20 (UNSAFE ADMITTED by the stages run) | SOURCE_SCOPE: exact approved refinement and sole incl: 1; SOURCE_SCOPE: only assertion-isolation attributes all: 2 | 0 |
| ghost axioms C-GATE-05 (7): NOT RUN here = `dafny translate` itself fails (exit 3 warnings x6, exit 2 x1; logs/A*.translate.7.log), so verify, build and audit refuse them | 7 (UNSAFE ADMITTED by the stages run) | - | 0 |

## V2 + expect rule, `@` lexer, `abstract`, size/nesting bounds (source part of diff ii)

| set | admitted | refused (cause: count) | NOT RUN (no translation) |
|---|---|---|---|
| B correct (67) | 66 | SOURCE_SCOPE: abstract modules are not allowed: 1 | 0 |
| C correct (10 + G11) | 11 | - | 0 |
| halting (24; includes the seven) | 14 (UNSAFE ADMITTED by the stages run) | SOURCE_SCOPE: run-time halt statement expect is not a: 10 | 0 |
| rule-2 review bypasses (23) | 20 (UNSAFE ADMITTED by the stages run) | SOURCE_SCOPE: exact approved refinement and sole incl: 1; SOURCE_SCOPE: only assertion-isolation attributes all: 2 | 0 |
| ghost axioms C-GATE-05 (7): NOT RUN here = `dafny translate` itself fails (exit 3 warnings x6, exit 2 x1; logs/A*.translate.7.log), so verify, build and audit refuse them | 7 (UNSAFE ADMITTED by the stages run) | - | 0 |

## V3 + JS bound tier (diff ii, complete)

| set | admitted | refused (cause: count) | NOT RUN (no translation) |
|---|---|---|---|
| B correct (67) | 20 | SOURCE_SCOPE: abstract modules are not allowed: 1 | 46 |
| C correct (10 + G11) | 11 | - | 0 |
| halting (24; includes the seven) | 0 | JS_CALL: 1; JS_LOOP: 6; JS_RECURSION: 2; JS_SHAPE: 1; JS_STATEMENT: 3; SOURCE_SCOPE: run-time halt statement expect is not a: 10 | 1 |
| rule-2 review bypasses (23) | 7 (bounded rule-2 bypasses A01s, A04, A05b, A06, X02, X06, X38: each ran in <= 29 ms, logs/drive_bounded.out) | JS_LOOP: 3; JS_NAME: 2; JS_SIZE: 3; SOURCE_SCOPE: exact approved refinement and sole incl: 1; SOURCE_SCOPE: only assertion-isolation attributes all: 2 | 5 |
| ghost axioms C-GATE-05 (7): NOT RUN here = `dafny translate` itself fails (exit 3 warnings x6, exit 2 x1; logs/A*.translate.7.log), so verify, build and audit refuse them | 0 | - | 7 |


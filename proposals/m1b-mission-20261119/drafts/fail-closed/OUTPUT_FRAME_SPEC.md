# OUTPUT_FRAME_SPEC — the present M1 output frame (worker X3, step B3)

Status: written 2026-11-19. Nothing here is proved. Classes are given per result.
No repository file was changed. HOL, Dafny and Docker were not run.

## (a) The present output language

### Sources (read with `git show` and from the pinned tree)

- `refund_render_fields_def` (`forge_refundWireProg.sml`, branch
  `origin/backup/forge-local-2026-11-11`, `.../exception-compiler-20261105/records/replay-sources/`):
  `refund_render_fields (ok,a,r,c,q,n) = sexp_to_string (refund_response ok a r c q n)`.
- `refund_response_def` (`forge_refund_io.sml`): `Expr [Atom «refund-result-v1»; Atom (True|False);
  Atom (toString a); Atom r; Atom c; Atom q; Atom (toString n)]`.
- `refund_fields_def` (`forge_refundCertifiedProg.sml`): if `ok` then `(T, amount, reason, charge,
  request, 1)` else `(F, 0, «», «», «», 0)`.
- `eligible` (transcribed in `scripts/exit_m1_conformance.py` `reference_eligible`): `ok` needs a
  non-empty charge id and request id, `0 <= amount <= remaining <= original <= MAX_MONEY`, the three
  flags true, and `reason` in the three approved reasons.
- `refund_main` (`forge_refundStdioProg.sml`): `TextIO.print (refund_dispatch wire)`. One print. No
  newline. On a decode error `refund_dispatch` raises `Fail`; nothing is printed.
- Printer `sexp_to_string` (`mlsexpScript.sml` lines ~380-400): `(` + atoms joined by ONE space + `)`.
  No pretty printing, no newline (that is `sexp_to_pretty_string`, not used).
- `make_str_safe`: `«»` prints as `""`; a string whose every char is safe prints bare; else
  `escape_str`. `is_safe_char c ⇔ c ∉ {( ) " NUL} ∧ ¬isSpace c`, `isSpace c ⇔ c = 32 ∨ 9 ≤ c ≤ 13`.
- `escape_str s = "\"" ++ FLAT (MAP char_escaped s) ++ "\""`; `char_escape_seq` maps ONLY
  TAB → `\t`, LF → `\n`, `\` → `\\`, `"` → `\"`. Every other byte (CR, VT, FF, NUL, space, `(`, `)`,
  bytes ≥ 0x80) is written raw inside the quotes.
- `mlint toString`: decimal, no leading zero, `~` for a negative value.

### Grammar (bytes; one byte = one CakeML char)

```
OUTPUT    ::= ""                      -- decode error: Fail raised, nothing printed (exit code 0)
            | ACCEPT | REJECT         -- one print, no trailing byte
REJECT    ::= "(refund-result-v1 False 0 \"\" \"\" \"\" 0)"          -- exactly these 37 bytes
ACCEPT    ::= "(refund-result-v1 True " AMOUNT " " REASON " " ID " " ID " 1)"
AMOUNT    ::= "0" | [1-9][0-9]*       -- value 0 .. 9223372036854775807 (at most 19 digits)
REASON    ::= "duplicate_charge" | "service_not_delivered" | "returned_item"   -- all bare
ID        ::= BARE | QUOTED           -- the value is non-empty; spelling = make_str_safe(value)
BARE      ::= SAFE+                   -- chosen iff every byte of the value is SAFE
SAFE      ::= any byte except ( ) " NUL SP TAB LF VT FF CR
QUOTED    ::= "\"" QCHAR* "\""        -- chosen iff some byte of the value is not SAFE
QCHAR     ::= "\\t" | "\\n" | "\\\\" | "\\\"" | any byte except TAB LF \ "
```

Notes. (1) Under a general `x`, `refund_render_fields x` also allows `False`, other amounts and
counts, negative integers (`~`) and empty atoms (`""`); the program only emits the two shapes above,
because of `refund_fields_def`. (2) The printer never emits `\0` or `\r`, but the reader accepts them.
(3) A bare atom may contain `\`, for example `back\slash`. (4) Lengths: REJECT is 37 bytes; ACCEPT is
`29 + len(AMOUNT) + len(REASON) + len(spell(charge)) + len(spell(request))` (46 bytes for
amount 40, `returned_item`, ids `c` and `r`, as observed); it is unbounded,
because the ids have no length bound in `eligible`.

## (b) Is the frame self-delimiting and prefix-free?

### Argument from the grammar (NOT proved)

The output is one `Expr`. Its first byte is `(` and its last byte is the matching `)`. No other byte
outside quotes is `)`: a bare atom excludes `)`, and a `)` in a value forces quotes. Inside quotes,
`"` and `\` are always escaped, so the lexer leaves a quoted atom only at its own closing quote. The
program's lexer `lex_aux` returns `INR` only at depth 0. Depth 0 comes back only at the matching `)`,
that is, at the last byte. For a strict prefix `p`:
- `p = ""`: `lex` gives `INR ([], [])`, then `parse` gives `INL «parse: empty input»`.
- `p ≠ ""`: the input ends at depth ≥ 1, or inside a quoted atom (`read_string_aux []` is `INL`), or
  just after a `\` (also `INL`). So `parse p = INL _`.
So no strict prefix parses, under the program's own reader, with or without `rest = []`.
The last field is the count `1`. A reader that does not need the final `)` can take a prefix that
ends after the count digit. A reader that does not need all seven fields can take a cut amount.

### Finite test (class: TESTED-UNPROVED)

Script: `run_prefix_test.py` (uses `frame.py`). Result file: `prefix_results.json`. Exit code 0.

- Part A: 68 requests run on the UNMODIFIED executable (SHA-256 `b8ed5ec2…7bb8`, checked; env
  `PATH=/usr/bin:/bin LANG=C LC_ALL=C CML_HEAP_SIZE=256 CML_STACK_SIZE=256`; timeout 60 s).
  62 authorized, 6 rejected. Ids: `c`, `a)b`, `"q"`, `a b`, `back\slash`, `r123`, `req-0001`, `1`,
  `True`, `(`, `)`, `\`, `\"`, TAB, LF, CR, NUL, `é` (UTF-8), 300 and 2000 bytes, `refund-result-v1`,
  `r 7`, `a\)`, `"`, `""`, space; each as charge id and as request id. Amounts 0, 9, 10, 60,
  1234567890123456789, MAX-1, MAX (19 digits). All three reasons. Rejections: amount over, disabled,
  empty charge id, bad reason, negative amount, over MAX. Every output: exit 0, empty stderr, byte-equal
  to the transcribed `render_fields`, accepted by the strict parser. 0 failures.
- Part B: every strict prefix (lengths 0 .. len-1) of every output: 8011 prefixes.

| Reader | Prefixes accepted | Accepted with wrong values | Smallest accepted prefix |
|---|---|---|---|
| strict reference parser (`frame.strict_parse`) | **0** | 0 | none |
| program reader, transcribed (`parse` then `refund_response_fields`, `rest = []`) | **0** | 0 | none |
| `startswith(b'(refund-result-v1 True ')` (copy of `m1_class`) | 6363 | 6363 (no values checked at all) | `(refund-result-v1 True ` (23 bytes) |
| split on spaces, strip `()`, amount = word 3 | 6301 | 111 | `(refund-result-v1 True 4` (24 bytes) → amount **4**, real amount 40 |
| regex `\(refund-result-v1 True (\d+) (\S+) (\S+) (\S+) (\d+)` without `$` | 58 | 26 | `(refund-result-v1 True 0 returned_item c r 1` (44 bytes, missing `)`) |
| auto-close reader (closes open quote and parentheses at end) | 62 | 0 | the full output minus the final `)` |

  Dangerous examples. Split-words: the prefix `(refund-result-v1 True 4` authorizes amount 4.
  Regex: for request id `r 7` the output is `(refund-result-v1 True 40 returned_item c1 "r 7" 1)`;
  the 47-byte prefix `(refund-result-v1 True 40 returned_item c1 "r 7` matches with request id `"r`
  and count 7. Auto-close: it accepts exactly one prefix per authorized output (62 = 62), the output
  without its last `)`, with correct values; it still accepts an incomplete frame.
- Part C (the REAL reader in the binary): the request and the response use the same `parse`. Every
  strict prefix of 4 requests (ids with space, `"`, `\`, `)`, TAB, LF; amount MAX) was sent to the
  executable: 268 runs, **0** with non-empty stdout. This exercises the compiled `parse` on prefixes of
  `sexp_to_string` output. It is a finite test of the binary, not of the response path.
- Part D (negative controls of the lemma, transcribed reader): (1) a printer with a trailing `\n`:
  the frame without `\n` is a strict prefix and parses with `rest = []` — detected (true). (2) a
  top-level atom: `parse "ab"` = `Atom ab`, rest `[]`, and `ab` is a prefix of `abc` — detected (true).
  So prefix-freeness depends on the top-level `Expr` and on no byte after the `)`.

Limits of the test. The transcribed reader is a transcription, not the HOL definition. The strict
parser is my code. 68 outputs are a finite set. Part C uses requests, not responses.

## (c) The HOL lemma that would make this a theorem (NOT proved)

Main statement, in the theory of `forge_refundWireProg`:

```
Theorem refund_render_fields_prefix_free:
  ∀x p. isPREFIX p (explode (refund_render_fields x)) ∧
        p ≠ explode (refund_render_fields x) ⇒ ISL (parse p)
```

It implies the form asked for: `¬∃se. parse p = INR (se, []) ∧ ISR (refund_response_fields se)`,
and even `¬∃se rest. parse p = INR (se, rest)`. The stronger `ISL` form is simpler to prove.

What it needs:
1. `parse_sexp_to_string` (exists, `mlsexpScript.sml` line 676) — only for the positive side
   (the full output parses). It is not enough: it says nothing about prefixes.
2. An unfolding lemma (new): `explode (sexp_to_string (Expr xs)) = "(" ++ J xs ++ ")"`, where
   `J` is the space-joined printing of the atoms (from `sexp_to_app_list_def`).
3. `read_symbol` on a prefix (new): for `EVERY is_safe_char t`, `read_symbol t acc = (implode
   (REVERSE acc ++ t), [])` (the rest is empty when the input ends inside a bare atom). Compare
   `read_symbol_thm` (exists; it needs a separator after the atom).
4. `read_string_aux` on a prefix (new): for a strict prefix `u` of `CONCAT (MAP char_escaped xs) ++
   "\""`, `ISL (read_string_aux u acc)`. Compare `read_string_aux_thm` (exists; the full string).
5. The key lemma (new, mutual induction on `sexp` and `sexp list`, like `lex_aux_sexp2tree`):
   `∀x d ts p. d ≠ 0 ∧ isPREFIX p (explode (sexp_to_string x)) ⇒ ISL (lex_aux d p ts)`, and the list
   form for every prefix of `J xs`. At depth ≥ 1 even the FULL printing gives `INL`, because the input
   ends before depth 0 comes back.
6. The main step: `p = ""` gives `INL «parse: empty input»`; `p = #"(" :: q` gives `lex_aux 1 q
   [OPEN]`, and `q` is a prefix of `J xs` (it lacks the last `)`), so lemma 5 applies.

Negative controls for the proof (each must FAIL to prove, or its negation must be provable by EVAL):
- N1: the same statement for `refund_render_fields x ^ «\n»`. Counterexample `p` = the frame
  itself: `parse p = INR (_, [])` by `refund_render_fields_roundtrip`.
- N2: the same statement for `sexp_to_string (Atom «abc»)`: `parse "ab" = INR (Atom «ab», [])`.
- N3: lemma 5 without `d ≠ 0`: false for `x = Atom «a»`, `d = 0`.

What the lemma would NOT give: completeness of the run (the stored theorem still allows a resource
stop with a prefix), the caller's checks (exit code, stderr, binding), or authentication.

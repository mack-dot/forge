// Night shift 2026-11-19, Orchestrator B, task b-ser. A DRAFT in an evidence folder. NOT gate evidence.
// A Dafny MODEL of the canonical token-body text that ts/refund-finality/encoding.ts makes (canon(body),
// encoding.ts:26-35 and :81). It is written to mirror encoding.ts line by line. It is NOT a proof about
// encoding.ts, Node, V8, JSON.stringify or Buffer.from: the relation of this model to the real code is
// TESTED (conformance run in conformance/), not proved.
//
// Model choices (each one is a reading of encoding.ts, not a fact checked by Dafny):
//  - A text value is a Dafny string with --unicode-char (default in Dafny 4): a sequence of Unicode SCALAR
//    values. encoding.ts:24 and :46 refuse a lone surrogate, so every accepted JavaScript text is such a
//    sequence. The model has no lone surrogate by construction.
//  - Money (encoding.ts:22, :47) is a decimal TEXT in the real body. The model keeps the number (nat) and
//    writes NatToDec(n) in quotes; Money(n) <==> n < 10^19 mirrors the regex ^(0|[1-9][0-9]{0,18})$.
//  - The output is the JavaScript text canon(body) as a sequence of scalar values. The bytes that are signed
//    are its UTF-8 form (encoding.ts:81). Utf8 below models that step; Utf8Injective is proved.
// No assume, no axiom, no bodiless lemma, no {:extern}, no expect in this file.
module SerModel {

  // ---- small option type with failure propagation ----
  datatype Option<T> = None | Some(value: T) {
    predicate IsFailure() { None? }
    function PropagateFailure<U>(): Option<U> requires None? { None }
    function Extract(): T requires Some? { value }
  }

  // ---- the body types (encoding.ts:8, :10, :14-17) ----
  // encoding.ts:8   ChargeState = { chargeId: string; original: string; remaining: string; refundEnabled: boolean }
  datatype ChargeState = ChargeState(chargeId: string, original: nat, remaining: nat, refundEnabled: bool)
  // encoding.ts:10  Intent = { chargeId: string; requestId: string; amount: string; reason: string }
  datatype Intent = Intent(chargeId: string, requestId: string, amount: nat, reason: string)
  // encoding.ts:14-17 TokenBody (seven fields)
  datatype TokenBody = TokenBody(domain: string, specLockSha256: string, checkerSha256: string,
                                 preStateSha256: string, requestId: string, post: ChargeState, intent: Intent)

  const DOMAIN: string := "FORGE_REFUND_FINALITY_SLICE1_V1"      // encoding.ts:20
  const MAX_TEXT: nat := 256                                      // encoding.ts:21
  const MONEY_BOUND: nat := 10000000000000000000                  // encoding.ts:22 (at most 19 digits)

  // =============================================================================================
  // Well-formedness: the accept set of isTokenBody (encoding.ts:38-68).
  // Length in UTF-16 code units (JavaScript v.length, encoding.ts:46).
  function Utf16Len(s: string): nat
  {
    if |s| == 0 then 0 else (if s[0] as int >= 0x10000 then 2 else 1) + Utf16Len(s[1..])
  }
  // encoding.ts:45-46 text(): length <= MAX_TEXT; no lone surrogate (true by construction); no U+0000.
  predicate Text(v: string) { Utf16Len(v) <= MAX_TEXT && (forall i | 0 <= i < |v| :: v[i] as int != 0) }
  // encoding.ts:47 money()
  predicate Money(n: nat) { n < MONEY_BOUND }
  // encoding.ts:23, :48 hex64()
  predicate IsLowerHex(c: char) { ('0' <= c <= '9') || ('a' <= c <= 'f') }
  predicate Hex64(v: string) { |v| == 64 && forall i | 0 <= i < |v| :: IsLowerHex(v[i]) }
  // encoding.ts:50-53 isState() (the key set is fixed by the datatype; refundEnabled is a bool by type)
  predicate IsState(s: ChargeState) { Text(s.chargeId) && Money(s.original) && Money(s.remaining) }
  // encoding.ts:57-60 isIntent()
  predicate IsIntent(i: Intent) { Text(i.chargeId) && Text(i.requestId) && Money(i.amount) && Text(i.reason) }
  // encoding.ts:64-68 isTokenBody()
  predicate WfBody(b: TokenBody)
  {
    b.domain == DOMAIN && Hex64(b.specLockSha256) && Hex64(b.checkerSha256) && Hex64(b.preStateSha256) &&
    Text(b.requestId) && IsState(b.post) && IsIntent(b.intent)
  }

  // =============================================================================================
  // JSON.stringify of a text (encoding.ts:27 for values, :32 for keys). ECMA-262 QuoteJSONString:
  // quote and backslash escaped; 0x08 0x09 0x0A 0x0C 0x0D by the short forms; every other code point
  // below 0x20 as \u00XX with LOWERCASE hex; everything else (U+007F, U+2028, U+2029, non-BMP) verbatim.
  function HexDigit(n: nat): char
    requires n < 16
  {
    if n < 10 then ('0' as int + n) as char else ('a' as int + (n - 10)) as char
  }
  function HexVal(c: char): nat
    requires IsLowerHex(c)
  {
    if '0' <= c <= '9' then c as int - '0' as int else c as int - 'a' as int + 10
  }
  predicate NamedControl(v: int) { v == 8 || v == 9 || v == 10 || v == 12 || v == 13 }

  function EscChar(c: char): string
  {
    if c == '"' then ['\\', '"']
    else if c == '\\' then ['\\', '\\']
    else if c as int == 8 then ['\\', 'b']
    else if c as int == 9 then ['\\', 't']
    else if c as int == 10 then ['\\', 'n']
    else if c as int == 12 then ['\\', 'f']
    else if c as int == 13 then ['\\', 'r']
    else if c as int < 0x20 then ['\\', 'u', '0', '0', HexDigit((c as int) / 16), HexDigit((c as int) % 16)]
    else [c]
  }
  function EscBody(s: string): string
    decreases |s|
  {
    if |s| == 0 then [] else EscChar(s[0]) + EscBody(s[1..])
  }
  // JSON.stringify(v) for a text v.
  opaque function Q(s: string): string { ['"'] + EscBody(s) + ['"'] }

  // Money as a decimal text (the value of the MONEY regex; minter.ts:38 dec()).
  function NatToDec(n: nat): string
    decreases n
  {
    if n < 10 then [HexDigit(n)] else NatToDec(n / 10) + [HexDigit(n % 10)]
  }
  // encoding.ts:28 boolean
  function SerBool(b: bool): string { if b then "true" else "false" }

  // Keys in the order of encoding.ts:31 (Object.keys(...).sort(); all keys are ASCII).
  // ChargeState sorted keys: chargeId, original, refundEnabled, remaining.
  const KS0: string := "{\"chargeId\":"
  const KS1: string := ",\"original\":"
  const KS2: string := ",\"refundEnabled\":"
  const KS3: string := ",\"remaining\":"
  // Intent sorted keys: amount, chargeId, reason, requestId.
  const KI0: string := "{\"amount\":"
  const KI1: string := ",\"chargeId\":"
  const KI2: string := ",\"reason\":"
  const KI3: string := ",\"requestId\":"
  // TokenBody sorted keys: checkerSha256, domain, intent, post, preStateSha256, requestId, specLockSha256.
  const KB0: string := "{\"checkerSha256\":"
  const KB1: string := ",\"domain\":"
  const KB2: string := ",\"intent\":"
  const KB3: string := ",\"post\":"
  const KB4: string := ",\"preStateSha256\":"
  const KB5: string := ",\"requestId\":"
  const KB6: string := ",\"specLockSha256\":"
  const KEND: string := "}"

  // encoding.ts:30-32 for a ChargeState (and encoding.ts:82: stateSha256 hashes this text).
  opaque function SerState(s: ChargeState): string
  {
    KS0 + (Q(s.chargeId) +                       // "chargeId": JSON.stringify(text)
    (KS1 + (Q(NatToDec(s.original)) +            // "original": money text
    (KS2 + (SerBool(s.refundEnabled) +           // "refundEnabled": true|false
    (KS3 + (Q(NatToDec(s.remaining)) +           // "remaining": money text
    KEND)))))))
  }
  // encoding.ts:30-32 for an Intent.
  opaque function SerIntent(i: Intent): string
  {
    KI0 + (Q(NatToDec(i.amount)) +
    (KI1 + (Q(i.chargeId) +
    (KI2 + (Q(i.reason) +
    (KI3 + (Q(i.requestId) +
    KEND)))))))
  }
  // encoding.ts:81 canon(body): the text whose UTF-8 bytes are signed.
  opaque function SerBody(b: TokenBody): string
  {
    KB0 + (Q(b.checkerSha256) +
    (KB1 + (Q(b.domain) +
    (KB2 + (SerIntent(b.intent) +
    (KB3 + (SerState(b.post) +
    (KB4 + (Q(b.preStateSha256) +
    (KB5 + (Q(b.requestId) +
    (KB6 + (Q(b.specLockSha256) +
    KEND)))))))))))))
  }

  // =============================================================================================
  // A strict decoder. It accepts exactly the canonical texts (ParseBodyRawCanonical below).
  opaque function Expect(lit: string, inp: string): Option<string>
  {
    if |lit| <= |inp| && inp[..|lit|] == lit then Some(inp[|lit|..]) else None
  }
  function SimpleUnescape(e: char): Option<char>
  {
    if e == '"' then Some('"') else if e == '\\' then Some('\\')
    else if e == 'b' then Some(8 as char) else if e == 't' then Some(9 as char)
    else if e == 'n' then Some(10 as char) else if e == 'f' then Some(12 as char)
    else if e == 'r' then Some(13 as char) else None
  }
  // Reads the inside of a JSON text up to and including the closing quote.
  function ParseStrBody(inp: string): Option<(string, string)>
    decreases |inp|
  {
    if |inp| == 0 then None
    else if inp[0] == '"' then Some(([], inp[1..]))
    else if inp[0] == '\\' then
      if |inp| < 2 then None
      else if SimpleUnescape(inp[1]).Some? then
        var rest :- ParseStrBody(inp[2..]);
        Some(([SimpleUnescape(inp[1]).value] + rest.0, rest.1))
      else if inp[1] == 'u' && |inp| >= 6 && inp[2] == '0' && inp[3] == '0' && IsLowerHex(inp[4]) &&
              IsLowerHex(inp[5]) && HexVal(inp[4]) * 16 + HexVal(inp[5]) < 0x20 &&
              !NamedControl(HexVal(inp[4]) * 16 + HexVal(inp[5])) then
        var rest :- ParseStrBody(inp[6..]);
        Some(([(HexVal(inp[4]) * 16 + HexVal(inp[5])) as char] + rest.0, rest.1))
      else None
    else if inp[0] as int < 0x20 then None
    else
      var rest :- ParseStrBody(inp[1..]);
      Some(([inp[0]] + rest.0, rest.1))
  }
  opaque function ParseStr(inp: string): Option<(string, string)>
  {
    var r :- Expect(['"'], inp);
    ParseStrBody(r)
  }
  predicate IsDigit(c: char) { '0' <= c <= '9' }
  predicate IsCanonDec(s: string)
  {
    |s| >= 1 && (forall i | 0 <= i < |s| :: IsDigit(s[i])) && (|s| == 1 || s[0] != '0')
  }
  function DecVal(s: string): nat
    requires forall i | 0 <= i < |s| :: IsDigit(s[i])
    decreases |s|
  {
    if |s| == 0 then 0 else assert IsDigit(s[|s| - 1]); DecVal(s[..|s| - 1]) * 10 + (s[|s| - 1] as int - '0' as int)
  }
  opaque function ParseMoney(inp: string): Option<(nat, string)>
  {
    var p :- ParseStr(inp);
    if IsCanonDec(p.0) then Some((DecVal(p.0), p.1)) else None
  }
  opaque function ParseBool(inp: string): Option<(bool, string)>
  {
    if Expect("true", inp).Some? then Some((true, Expect("true", inp).value))
    else if Expect("false", inp).Some? then Some((false, Expect("false", inp).value))
    else None
  }
  opaque function ParseState(inp: string): Option<(ChargeState, string)>
  {
    var r0 :- Expect(KS0, inp);
    var a :- ParseStr(r0);
    var r1 :- Expect(KS1, a.1);
    var b :- ParseMoney(r1);
    var r2 :- Expect(KS2, b.1);
    var c :- ParseBool(r2);
    var r3 :- Expect(KS3, c.1);
    var d :- ParseMoney(r3);
    var r4 :- Expect(KEND, d.1);
    Some((ChargeState(a.0, b.0, d.0, c.0), r4))
  }
  opaque function ParseIntent(inp: string): Option<(Intent, string)>
  {
    var r0 :- Expect(KI0, inp);
    var a :- ParseMoney(r0);
    var r1 :- Expect(KI1, a.1);
    var b :- ParseStr(r1);
    var r2 :- Expect(KI2, b.1);
    var c :- ParseStr(r2);
    var r3 :- Expect(KI3, c.1);
    var d :- ParseStr(r3);
    var r4 :- Expect(KEND, d.1);
    Some((Intent(b.0, d.0, a.0, c.0), r4))
  }
  opaque function ParseBodyRaw(inp: string): Option<(TokenBody, string)>
  {
    var r0 :- Expect(KB0, inp);
    var chk :- ParseStr(r0);
    var r1 :- Expect(KB1, chk.1);
    var dom :- ParseStr(r1);
    var r2 :- Expect(KB2, dom.1);
    var it :- ParseIntent(r2);
    var r3 :- Expect(KB3, it.1);
    var st :- ParseState(r3);
    var r4 :- Expect(KB4, st.1);
    var pre :- ParseStr(r4);
    var r5 :- Expect(KB5, pre.1);
    var rq :- ParseStr(r5);
    var r6 :- Expect(KB6, rq.1);
    var sp :- ParseStr(r6);
    var r7 :- Expect(KEND, sp.1);
    Some((TokenBody(dom.0, sp.0, chk.0, pre.0, rq.0, st.0, it.0), r7))
  }
  // The decoder of a whole text: the strict parse, nothing after the body, and isTokenBody.
  function Parse(inp: string): Option<TokenBody>
  {
    var p :- ParseBodyRaw(inp);
    if p.1 == [] && WfBody(p.0) then Some(p.0) else None
  }

  // =============================================================================================
  // Round trip, part 1: the pieces.
  lemma Assoc(a: string, b: string, c: string)
    ensures (a + b) + c == a + (b + c)
  {}

  lemma ExpectRT(lit: string, r: string)
    ensures Expect(lit, lit + r) == Some(r)
  {
    reveal Expect();
    assert (lit + r)[..|lit|] == lit;
    assert (lit + r)[|lit|..] == r;
  }

  lemma HexDigitRT(n: nat)
    requires n < 16
    ensures IsLowerHex(HexDigit(n)) && HexVal(HexDigit(n)) == n
  {}

  lemma EscCharRT(c: char, r: string)
    ensures ParseStrBody(EscChar(c) + r) == (var p := ParseStrBody(r); if p.None? then None else Some(([c] + p.value.0, p.value.1)))
  {
    var inp := EscChar(c) + r;
    var v := c as int;
    if c == '"' || c == '\\' || v == 8 || v == 9 || v == 10 || v == 12 || v == 13 {
      assert inp[2..] == r;
      assert SimpleUnescape(inp[1]).Some? && SimpleUnescape(inp[1]).value == c;
    } else if v < 0x20 {
      HexDigitRT(v / 16);
      HexDigitRT(v % 16);
      assert inp[0] == '\\' && inp[1] == 'u' && inp[2] == '0' && inp[3] == '0';
      assert inp[4] == HexDigit(v / 16) && inp[5] == HexDigit(v % 16);
      assert HexVal(inp[4]) * 16 + HexVal(inp[5]) == v;
      assert SimpleUnescape(inp[1]).None?;
      assert inp[6..] == r;
      assert (v as char) == c;
    } else {
      assert inp[0] == c && inp[1..] == r;
    }
  }

  lemma EscBodyRT(s: string, r: string)
    ensures ParseStrBody(EscBody(s) + ['"'] + r) == Some((s, r))
    decreases |s|
  {
    if |s| == 0 {
      assert EscBody(s) + ['"'] + r == ['"'] + r;
      assert (['"'] + r)[1..] == r;
    } else {
      var tail := EscBody(s[1..]) + ['"'] + r;
      assert EscBody(s) + ['"'] + r == EscChar(s[0]) + tail;
      EscCharRT(s[0], tail);
      EscBodyRT(s[1..], r);
      assert [s[0]] + s[1..] == s;
    }
  }

  lemma ParseStrRT(s: string, r: string)
    ensures ParseStr(Q(s) + r) == Some((s, r))
  {
    reveal ParseStr(), Q();
    assert Q(s) + r == ['"'] + (EscBody(s) + ['"'] + r);
    ExpectRT(['"'], EscBody(s) + ['"'] + r);
    EscBodyRT(s, r);
  }

  lemma DigitsOfNatToDec(n: nat)
    ensures IsCanonDec(NatToDec(n))
    ensures DecVal(NatToDec(n)) == n
    ensures NatToDec(n)[0] == '0' ==> n == 0
    decreases n
  {
    if n >= 10 {
      DigitsOfNatToDec(n / 10);
      var p := NatToDec(n / 10);
      var s := p + [HexDigit(n % 10)];
      assert s[..|s| - 1] == p;
      assert s[0] == p[0];
    }
  }

  lemma ParseMoneyRT(n: nat, r: string)
    ensures ParseMoney(Q(NatToDec(n)) + r) == Some((n, r))
  {
    reveal ParseMoney();
    ParseStrRT(NatToDec(n), r);
    DigitsOfNatToDec(n);
  }

  lemma ParseBoolRT(b: bool, r: string)
    ensures ParseBool(SerBool(b) + r) == Some((b, r))
  {
    reveal ParseBool();
    ExpectRT(SerBool(b), r);
    if !b {
      var inp := SerBool(b) + r;
      assert Expect("true", inp).None? by { reveal Expect(); assert inp[3] == 's'; }
    }
  }

  // Round trip, part 2: the composite values.
  lemma ParseStateRT(s: ChargeState, r: string)
    ensures ParseState(SerState(s) + r) == Some((s, r))
  {
    var t8 := KEND + r;
    var t7 := Q(NatToDec(s.remaining)) + t8;
    var t6 := KS3 + t7;
    var t5 := SerBool(s.refundEnabled) + t6;
    var t4 := KS2 + t5;
    var t3 := Q(NatToDec(s.original)) + t4;
    var t2 := KS1 + t3;
    var t1 := Q(s.chargeId) + t2;
    var t0 := KS0 + t1;
    reveal SerState(), ParseState();
    assert SerState(s) + r == t0;
    ExpectRT(KS0, t1);
    ParseStrRT(s.chargeId, t2);
    ExpectRT(KS1, t3);
    ParseMoneyRT(s.original, t4);
    ExpectRT(KS2, t5);
    ParseBoolRT(s.refundEnabled, t6);
    ExpectRT(KS3, t7);
    ParseMoneyRT(s.remaining, t8);
    ExpectRT(KEND, r);
  }

  lemma ParseIntentRT(i: Intent, r: string)
    ensures ParseIntent(SerIntent(i) + r) == Some((i, r))
  {
    var t8 := KEND + r;
    var t7 := Q(i.requestId) + t8;
    var t6 := KI3 + t7;
    var t5 := Q(i.reason) + t6;
    var t4 := KI2 + t5;
    var t3 := Q(i.chargeId) + t4;
    var t2 := KI1 + t3;
    var t1 := Q(NatToDec(i.amount)) + t2;
    var t0 := KI0 + t1;
    reveal SerIntent(), ParseIntent();
    assert SerIntent(i) + r == t0;
    ExpectRT(KI0, t1);
    ParseMoneyRT(i.amount, t2);
    ExpectRT(KI1, t3);
    ParseStrRT(i.chargeId, t4);
    ExpectRT(KI2, t5);
    ParseStrRT(i.reason, t6);
    ExpectRT(KI3, t7);
    ParseStrRT(i.requestId, t8);
    ExpectRT(KEND, r);
  }

  lemma ParseBodyRawRT(b: TokenBody, r: string)
    ensures ParseBodyRaw(SerBody(b) + r) == Some((b, r))
  {
    var t14 := KEND + r;
    var t13 := Q(b.specLockSha256) + t14;
    var t12 := KB6 + t13;
    var t11 := Q(b.requestId) + t12;
    var t10 := KB5 + t11;
    var t9 := Q(b.preStateSha256) + t10;
    var t8 := KB4 + t9;
    var t7 := SerState(b.post) + t8;
    var t6 := KB3 + t7;
    var t5 := SerIntent(b.intent) + t6;
    var t4 := KB2 + t5;
    var t3 := Q(b.domain) + t4;
    var t2 := KB1 + t3;
    var t1 := Q(b.checkerSha256) + t2;
    var t0 := KB0 + t1;
    reveal SerBody(), ParseBodyRaw();
    assert SerBody(b) + r == t0;
    ExpectRT(KB0, t1);
    ParseStrRT(b.checkerSha256, t2);
    ExpectRT(KB1, t3);
    ParseStrRT(b.domain, t4);
    ExpectRT(KB2, t5);
    ParseIntentRT(b.intent, t6);
    ExpectRT(KB3, t7);
    ParseStateRT(b.post, t8);
    ExpectRT(KB4, t9);
    ParseStrRT(b.preStateSha256, t10);
    ExpectRT(KB5, t11);
    ParseStrRT(b.requestId, t12);
    ExpectRT(KB6, t13);
    ParseStrRT(b.specLockSha256, t14);
    ExpectRT(KEND, r);
  }

  // G1(b): the round trip on well-formed bodies.
  lemma RoundTrip(b: TokenBody)
    requires WfBody(b)
    ensures Parse(SerBody(b)) == Some(b)
  {
    ParseBodyRawRT(b, []);
    assert SerBody(b) + [] == SerBody(b);
  }

  // G1(a): injectivity. It holds on ALL bodies (well-formedness is not needed for it).
  lemma SerBodyInjective(b1: TokenBody, b2: TokenBody)
    requires SerBody(b1) == SerBody(b2)
    ensures b1 == b2
  {
    ParseBodyRawRT(b1, []);
    ParseBodyRawRT(b2, []);
    assert SerBody(b1) + [] == SerBody(b1);
    assert SerBody(b2) + [] == SerBody(b2);
  }

  lemma SerStateInjective(s1: ChargeState, s2: ChargeState)
    requires SerState(s1) == SerState(s2)
    ensures s1 == s2
  {
    ParseStateRT(s1, []);
    ParseStateRT(s2, []);
    assert SerState(s1) + [] == SerState(s1);
    assert SerState(s2) + [] == SerState(s2);
  }

  // =============================================================================================
  // G4 support: the decoder accepts ONLY canonical texts. Parse(inp) == Some(b) ==> inp == SerBody(b).
  lemma ExpectCanon(lit: string, inp: string)
    requires Expect(lit, inp).Some?
    ensures inp == lit + Expect(lit, inp).value
  {
    reveal Expect();
    assert inp == inp[..|lit|] + inp[|lit|..];
  }

  lemma HexValRT(c: char)
    requires IsLowerHex(c)
    ensures HexVal(c) < 16 && HexDigit(HexVal(c)) == c
  {}

  lemma ParseStrBodyCanon(inp: string)
    requires ParseStrBody(inp).Some?
    ensures inp == EscBody(ParseStrBody(inp).value.0) + ['"'] + ParseStrBody(inp).value.1
    decreases |inp|
  {
    var res := ParseStrBody(inp).value;
    if inp[0] == '"' {
      assert inp == ['"'] + inp[1..];
    } else if inp[0] == '\\' {
      if SimpleUnescape(inp[1]).Some? {
        var ch := SimpleUnescape(inp[1]).value;
        ParseStrBodyCanon(inp[2..]);
        var sub := ParseStrBody(inp[2..]).value;
        assert res == ([ch] + sub.0, sub.1);
        assert EscChar(ch) == inp[..2];
        assert ([ch] + sub.0)[1..] == sub.0;
        assert EscBody(res.0) == EscChar(ch) + EscBody(sub.0);
        assert inp == inp[..2] + inp[2..];
      } else {
        var v := HexVal(inp[4]) * 16 + HexVal(inp[5]);
        HexValRT(inp[4]);
        HexValRT(inp[5]);
        assert v / 16 == HexVal(inp[4]) && v % 16 == HexVal(inp[5]);
        var ch := v as char;
        ParseStrBodyCanon(inp[6..]);
        var sub := ParseStrBody(inp[6..]).value;
        assert res == ([ch] + sub.0, sub.1);
        assert EscChar(ch) == inp[..6];
        assert ([ch] + sub.0)[1..] == sub.0;
        assert EscBody(res.0) == EscChar(ch) + EscBody(sub.0);
        assert inp == inp[..6] + inp[6..];
      }
    } else {
      ParseStrBodyCanon(inp[1..]);
      var sub := ParseStrBody(inp[1..]).value;
      assert res == ([inp[0]] + sub.0, sub.1);
      assert EscChar(inp[0]) == [inp[0]];
      assert ([inp[0]] + sub.0)[1..] == sub.0;
      assert EscBody(res.0) == EscChar(inp[0]) + EscBody(sub.0);
      assert inp == [inp[0]] + inp[1..];
    }
  }

  lemma ParseStrCanon(inp: string)
    requires ParseStr(inp).Some?
    ensures inp == Q(ParseStr(inp).value.0) + ParseStr(inp).value.1
  {
    reveal ParseStr(), Q();
    ExpectCanon(['"'], inp);
    var r := Expect(['"'], inp).value;
    ParseStrBodyCanon(r);
  }

  lemma DecPositive(p: string)
    requires |p| >= 1 && (forall i | 0 <= i < |p| :: IsDigit(p[i])) && p[0] != '0'
    ensures DecVal(p) >= 1
    decreases |p|
  {
    if |p| > 1 {
      var q := p[..|p| - 1];
      assert q[0] == p[0];
      DecPositive(q);
    }
  }

  lemma DecCanon(s: string)
    requires IsCanonDec(s)
    ensures NatToDec(DecVal(s)) == s
    decreases |s|
  {
    var p := s[..|s| - 1];
    var d := s[|s| - 1] as int - '0' as int;
    if |s| == 1 {
      assert DecVal(s) == DecVal(p) * 10 + d;
      assert s == [HexDigit(d)];
    } else {
      assert p[0] == s[0];
      DecPositive(p);
      DecCanon(p);
      assert DecVal(s) == DecVal(p) * 10 + d;
      assert DecVal(s) / 10 == DecVal(p) && DecVal(s) % 10 == d;
      assert s == p + [HexDigit(d)];
    }
  }

  lemma ParseMoneyCanon(inp: string)
    requires ParseMoney(inp).Some?
    ensures inp == Q(NatToDec(ParseMoney(inp).value.0)) + ParseMoney(inp).value.1
  {
    reveal ParseMoney();
    ParseStrCanon(inp);
    DecCanon(ParseStr(inp).value.0);
  }

  lemma ParseBoolCanon(inp: string)
    requires ParseBool(inp).Some?
    ensures inp == SerBool(ParseBool(inp).value.0) + ParseBool(inp).value.1
  {
    reveal ParseBool();
    if Expect("true", inp).Some? { ExpectCanon("true", inp); } else { ExpectCanon("false", inp); }
  }

  lemma ParseStateCanon(inp: string)
    requires ParseState(inp).Some?
    ensures inp == SerState(ParseState(inp).value.0) + ParseState(inp).value.1
  {
    reveal ParseState(), SerState();
    ExpectCanon(KS0, inp);
    var r0 := Expect(KS0, inp).value;
    ParseStrCanon(r0); var a := ParseStr(r0).value;
    ExpectCanon(KS1, a.1); var r1 := Expect(KS1, a.1).value;
    ParseMoneyCanon(r1); var b := ParseMoney(r1).value;
    ExpectCanon(KS2, b.1); var r2 := Expect(KS2, b.1).value;
    ParseBoolCanon(r2); var c := ParseBool(r2).value;
    ExpectCanon(KS3, c.1); var r3 := Expect(KS3, c.1).value;
    ParseMoneyCanon(r3); var d := ParseMoney(r3).value;
    ExpectCanon(KEND, d.1); var r4 := Expect(KEND, d.1).value;
    var st := ChargeState(a.0, b.0, d.0, c.0);
    assert ParseState(inp).value == (st, r4);
    assert inp == SerState(st) + r4;
  }

  lemma ParseIntentCanon(inp: string)
    requires ParseIntent(inp).Some?
    ensures inp == SerIntent(ParseIntent(inp).value.0) + ParseIntent(inp).value.1
  {
    reveal ParseIntent(), SerIntent();
    ExpectCanon(KI0, inp);
    var r0 := Expect(KI0, inp).value;
    ParseMoneyCanon(r0); var a := ParseMoney(r0).value;
    ExpectCanon(KI1, a.1); var r1 := Expect(KI1, a.1).value;
    ParseStrCanon(r1); var b := ParseStr(r1).value;
    ExpectCanon(KI2, b.1); var r2 := Expect(KI2, b.1).value;
    ParseStrCanon(r2); var c := ParseStr(r2).value;
    ExpectCanon(KI3, c.1); var r3 := Expect(KI3, c.1).value;
    ParseStrCanon(r3); var d := ParseStr(r3).value;
    ExpectCanon(KEND, d.1); var r4 := Expect(KEND, d.1).value;
    var it := Intent(b.0, d.0, a.0, c.0);
    assert ParseIntent(inp).value == (it, r4);
    assert inp == SerIntent(it) + r4;
  }

  lemma ParseBodyRawCanon(inp: string)
    requires ParseBodyRaw(inp).Some?
    ensures inp == SerBody(ParseBodyRaw(inp).value.0) + ParseBodyRaw(inp).value.1
  {
    reveal ParseBodyRaw(), SerBody();
    ExpectCanon(KB0, inp); var r0 := Expect(KB0, inp).value;
    ParseStrCanon(r0); var chk := ParseStr(r0).value;
    ExpectCanon(KB1, chk.1); var r1 := Expect(KB1, chk.1).value;
    ParseStrCanon(r1); var dom := ParseStr(r1).value;
    ExpectCanon(KB2, dom.1); var r2 := Expect(KB2, dom.1).value;
    ParseIntentCanon(r2); var it := ParseIntent(r2).value;
    ExpectCanon(KB3, it.1); var r3 := Expect(KB3, it.1).value;
    ParseStateCanon(r3); var st := ParseState(r3).value;
    ExpectCanon(KB4, st.1); var r4 := Expect(KB4, st.1).value;
    ParseStrCanon(r4); var pre := ParseStr(r4).value;
    ExpectCanon(KB5, pre.1); var r5 := Expect(KB5, pre.1).value;
    ParseStrCanon(r5); var rq := ParseStr(r5).value;
    ExpectCanon(KB6, rq.1); var r6 := Expect(KB6, rq.1).value;
    ParseStrCanon(r6); var sp := ParseStr(r6).value;
    ExpectCanon(KEND, sp.1); var r7 := Expect(KEND, sp.1).value;
    var b := TokenBody(dom.0, sp.0, chk.0, pre.0, rq.0, st.0, it.0);
    assert ParseBodyRaw(inp).value == (b, r7);
    assert inp == SerBody(b) + r7;
  }

  // The decoder accepts exactly the serializations of well-formed bodies.
  lemma ParseExact(inp: string, b: TokenBody)
    ensures Parse(inp) == Some(b) <==> (WfBody(b) && inp == SerBody(b))
  {
    if Parse(inp) == Some(b) {
      ParseBodyRawCanon(inp);
      assert inp == SerBody(b) + [];
    }
    if WfBody(b) && inp == SerBody(b) { RoundTrip(b); }
  }

  // =============================================================================================
  // The signed bytes: UTF-8 of the canonical text (encoding.ts:81, Buffer.from(text, "utf8")).
  // canon() never yields a lone surrogate (JSON.stringify escapes one; isTokenBody refuses one), so the
  // text is a sequence of scalar values and Buffer.from is standard UTF-8 on it.
  function Utf8Char(c: char): seq<int>
  {
    var v := c as int;
    if v < 0x80 then [v]
    else if v < 0x800 then [0xC0 + v / 64, 0x80 + v % 64]
    else if v < 0x10000 then [0xE0 + v / 4096, 0x80 + (v / 64) % 64, 0x80 + v % 64]
    else [0xF0 + v / 262144, 0x80 + (v / 4096) % 64, 0x80 + (v / 64) % 64, 0x80 + v % 64]
  }
  function Utf8(s: string): seq<int>
    decreases |s|
  {
    if |s| == 0 then [] else Utf8Char(s[0]) + Utf8(s[1..])
  }
  function LeadLen(b: int): nat
  {
    if b < 0x80 then 1 else if b < 0xE0 then 2 else if b < 0xF0 then 3 else 4
  }
  function DecodeFirst(m: seq<int>): int
    requires |m| >= 1 && |m| >= LeadLen(m[0])
  {
    var n := LeadLen(m[0]);
    if n == 1 then m[0]
    else if n == 2 then (m[0] - 0xC0) * 64 + (m[1] - 0x80)
    else if n == 3 then (m[0] - 0xE0) * 4096 + (m[1] - 0x80) * 64 + (m[2] - 0x80)
    else (m[0] - 0xF0) * 262144 + (m[1] - 0x80) * 4096 + (m[2] - 0x80) * 64 + (m[3] - 0x80)
  }
  lemma Utf8CharDecode(c: char, r: seq<int>)
    ensures |Utf8Char(c)| >= 1
    ensures LeadLen((Utf8Char(c) + r)[0]) == |Utf8Char(c)|
    ensures DecodeFirst(Utf8Char(c) + r) == c as int
  {
    var v := c as int;
    var m := Utf8Char(c) + r;
    if v >= 0x10000 {
      var a := v / 64;
      var b := a / 64;
      assert v == a * 64 + v % 64;
      assert a == b * 64 + a % 64;
      assert v / 4096 == b;
      assert b == (b / 64) * 64 + b % 64;
      assert v / 262144 == b / 64;
      assert (v / 262144) <= 4;
      assert m[0] == 0xF0 + b / 64 && m[1] == 0x80 + b % 64 && m[2] == 0x80 + a % 64 && m[3] == 0x80 + v % 64;
    } else if v >= 0x800 {
      var a := v / 64;
      assert v == a * 64 + v % 64;
      assert a == (a / 64) * 64 + a % 64;
      assert v / 4096 == a / 64;
    }
  }
  lemma Utf8Injective(s1: string, s2: string)
    requires Utf8(s1) == Utf8(s2)
    ensures s1 == s2
    decreases |s1|
  {
    if |s1| == 0 {
      if |s2| > 0 { Utf8CharDecode(s2[0], Utf8(s2[1..])); }
    } else {
      Utf8CharDecode(s1[0], Utf8(s1[1..]));
      if |s2| == 0 { assert |Utf8(s1)| >= 1; }
      else {
        Utf8CharDecode(s2[0], Utf8(s2[1..]));
        var m := Utf8(s1);
        assert m == Utf8Char(s1[0]) + Utf8(s1[1..]);
        assert m == Utf8Char(s2[0]) + Utf8(s2[1..]);
        assert s1[0] as int == s2[0] as int;
        assert s1[0] == s2[0];
        var n := |Utf8Char(s1[0])|;
        assert Utf8(s1[1..]) == m[n..];
        assert Utf8(s2[1..]) == m[n..];
        Utf8Injective(s1[1..], s2[1..]);
        assert s1 == [s1[0]] + s1[1..];
        assert s2 == [s2[0]] + s2[1..];
      }
    }
  }
  function SignedBytes(b: TokenBody): seq<int> { Utf8(SerBody(b)) }

  // G1 main statement: signed bytes determine the body (all bodies).
  lemma SignedBytesInjective(b1: TokenBody, b2: TokenBody)
    requires SignedBytes(b1) == SignedBytes(b2)
    ensures b1 == b2
  {
    Utf8Injective(SerBody(b1), SerBody(b2));
    SerBodyInjective(b1, b2);
  }

  // =============================================================================================
  // Controls (G1 c): two NON-injective variants. Each has a proved collision of two different
  // well-formed bodies.
  // (c1) the same layout with NO escaping of a text (a quote inside a text is written as it is).
  function Q0(s: string): string { ['"'] + s + ['"'] }
  function SerIntentNoEsc(i: Intent): string
  {
    KI0 + (Q0(NatToDec(i.amount)) + (KI1 + (Q0(i.chargeId) + (KI2 + (Q0(i.reason) + (KI3 + (Q0(i.requestId) + KEND)))))))
  }
  // (c2) fields concatenated with no delimiter.
  function SerIntentConcat(i: Intent): string { i.reason + i.requestId }

  const ZERO64: string := seq(64, _ => '0')
  const CI1: Intent := Intent("ch_1", "z", 0, R1)
  const CI2: Intent := Intent("ch_1", R2, 0, "x")
  const CB1: TokenBody := TokenBody(DOMAIN, ZERO64, ZERO64, ZERO64, "z", ChargeState("ch_1", 100, 100, true), CI1)
  const CB2: TokenBody := TokenBody(DOMAIN, ZERO64, ZERO64, ZERO64, "z", ChargeState("ch_1", 100, 100, true), CI2)

  lemma Utf16LenAtMost(s: string)
    ensures Utf16Len(s) <= 2 * |s|
    decreases |s|
  {
    if |s| > 0 { Utf16LenAtMost(s[1..]); }
  }

  lemma TextSmall(v: string)
    requires 2 * |v| <= MAX_TEXT && forall i | 0 <= i < |v| :: v[i] as int != 0
    ensures Text(v)
  {
    Utf16LenAtMost(v);
  }
  lemma Zero64Hex()
    ensures Hex64(ZERO64)
  {}
  lemma ControlIntentsDiffer()
    ensures CI1 != CI2
  {
    assert |CI1.requestId| == 1 && |CI2.requestId| != 1;
  }
  const R1: string := "x\",\"requestId\":\"y"
  const R2: string := "y\",\"requestId\":\"z"
  lemma TextR1() ensures Text(R1) { TextSmall(R1); }
  lemma TextR2() ensures Text(R2) { TextSmall(R2); }
  lemma TextShort() ensures Text("ch_1") && Text("z") && Text("x") { TextSmall("ch_1"); TextSmall("z"); TextSmall("x"); }
  lemma ControlIntentsWf()
    ensures IsIntent(CI1) && IsIntent(CI2)
  {
    TextR1(); TextR2(); TextShort();
  }
  lemma ControlBodiesWf()
    ensures WfBody(CB1) && WfBody(CB2) && CB1 != CB2
  {
    ControlIntentsWf(); ControlIntentsDiffer(); Zero64Hex(); TextSmall("z"); TextSmall("ch_1");
  }
  // The common text of both: {"amount":"0","chargeId":"ch_1","reason":"x","requestId":"y","requestId":"z"}
  const TAIL: string := "\"x\",\"requestId\":\"y\",\"requestId\":\"z\"}"
  lemma Tail1() ensures Q0(R1) + (KI3 + (Q0("z") + KEND)) == TAIL {}
  lemma Tail2() ensures Q0("x") + (KI3 + (Q0(R2) + KEND)) == TAIL {}
  lemma ControlNoEscapeEqual()
    ensures SerIntentNoEsc(CI1) == SerIntentNoEsc(CI2)
  {
    Tail1(); Tail2();
    assert Q0(CI1.reason) + (KI3 + (Q0(CI1.requestId) + KEND)) == Q0(CI2.reason) + (KI3 + (Q0(CI2.requestId) + KEND));
  }
  lemma ControlNoEscapeCollides()
    ensures CI1 != CI2 && CB1 != CB2
    ensures IsIntent(CI1) && IsIntent(CI2) && WfBody(CB1) && WfBody(CB2)
    ensures SerIntentNoEsc(CI1) == SerIntentNoEsc(CI2)
    ensures SerIntent(CI1) != SerIntent(CI2)
    ensures SerBody(CB1) != SerBody(CB2)
  {
    ControlIntentsDiffer(); ControlIntentsWf(); ControlBodiesWf(); ControlNoEscapeEqual();
    if SerIntent(CI1) == SerIntent(CI2) {
      ParseIntentRT(CI1, []); ParseIntentRT(CI2, []);
      assert SerIntent(CI1) + [] == SerIntent(CI1);
      assert SerIntent(CI2) + [] == SerIntent(CI2);
    }
    if SerBody(CB1) == SerBody(CB2) { SerBodyInjective(CB1, CB2); }
  }

  lemma ControlConcatCollides()
    ensures SerIntentConcat(Intent("ch_1", "c", 0, "ab")) == SerIntentConcat(Intent("ch_1", "bc", 0, "a"))
    ensures Intent("ch_1", "c", 0, "ab") != Intent("ch_1", "bc", 0, "a")
  {
    assert "ab" + "c" == "a" + "bc";
  }

  // Non-vacuity witness: a well-formed body with amount 0 that the decoder accepts.
  const WB: TokenBody := TokenBody(DOMAIN, ZERO64, ZERO64, ZERO64, "rq_1",
                                   ChargeState("ch_1", 100, 100, true), Intent("ch_1", "rq_1", 0, "duplicate_charge"))
  lemma WitnessWf()
    ensures WfBody(WB) && WB.intent.amount == 0
  {
    TextSmall("rq_1"); TextSmall("ch_1"); TextSmall("duplicate_charge"); Zero64Hex();
  }
  lemma WitnessZeroAmount()
    ensures WfBody(WB) && WB.intent.amount == 0
    ensures Parse(SerBody(WB)) == Some(WB)
    ensures Parse(SerBody(WB) + " ") == None          // a trailing character is refused
  {
    WitnessWf();
    RoundTrip(WB);
    ParseBodyRawRT(WB, " ");
  }
}

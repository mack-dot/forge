include "Library.dfy"

// This file proves relations over the unchanged published UTF-8 functions.
// It defines no decoder and imports no axiom-bearing character wrapper.
module RefundUnicode {
  import B = Std.Unicode.Base
  import U = Std.Unicode.Utf8EncodingForm
  import S = Std.Collections.Seq

  @IsolateAssertions
  lemma {:induction false} Int24RoundTrip(n: nat)
    requires n < 0x1000000
    ensures (n as bv24) as int == n
    decreases n
  {
    if n != 0 {
      Int24RoundTrip(n - 1);
      assert n as bv24 == ((n - 1) as bv24) + 1;
      assert (((n - 1) as bv24) + 1) as int == n;
    }
  }

  @IsolateAssertions
  @ResourceLimit("20e6")
  lemma CharScalar(c: char)
    ensures (c as int as bv24) as int == c as int
    ensures c as int as bv24 <= 0x10ffff
    ensures c as int as bv24 < 0xd800 || 0xdfff < c as int as bv24
  {
    assert 0 <= c as int < 0x110000;
    assert c as int < 0xd800 || 0xe000 <= c as int;
    Int24RoundTrip(c as int);
    assert (c as int as bv24) as int == c as int;
  }

  function Scalar(c: char): B.ScalarValue
    ensures Scalar(c) as int == c as int
  {
    CharScalar(c);
    c as int as B.ScalarValue
  }

  @IsolateAssertions
  @ResourceLimit("20e6")
  lemma ScalarRoundTrip(v: B.ScalarValue)
    ensures U.DecodeMinimalWellFormedCodeUnitSubsequence(U.EncodeScalarValue(v)) == v
  {
    if v <= 0x7f {
      var bs := U.EncodeScalarValueSingleByte(v);
      assert U.DecodeMinimalWellFormedCodeUnitSubsequenceSingleByte(bs) == v;
      assert U.DecodeMinimalWellFormedCodeUnitSubsequence(U.EncodeScalarValue(v)) == v;
    } else if v <= 0x7ff {
      var bs := U.EncodeScalarValueDoubleByte(v);
      assert U.DecodeMinimalWellFormedCodeUnitSubsequenceDoubleByte(bs) == v;
      assert U.DecodeMinimalWellFormedCodeUnitSubsequence(U.EncodeScalarValue(v)) == v;
    } else if v <= 0xffff {
      var bs := U.EncodeScalarValueTripleByte(v);
      assert U.DecodeMinimalWellFormedCodeUnitSubsequenceTripleByte(bs) == v;
      assert U.DecodeMinimalWellFormedCodeUnitSubsequence(U.EncodeScalarValue(v)) == v;
    } else {
      var bs := U.EncodeScalarValueQuadrupleByte(v);
      assert U.DecodeMinimalWellFormedCodeUnitSubsequenceQuadrupleByte(bs) == v;
      assert U.DecodeMinimalWellFormedCodeUnitSubsequence(U.EncodeScalarValue(v)) == v;
    }
  }

  lemma ScalarInjective(a: B.ScalarValue, b: B.ScalarValue)
    ensures U.EncodeScalarValue(a) == U.EncodeScalarValue(b) ==> a == b
  {
    ScalarRoundTrip(a);
    ScalarRoundTrip(b);
  }
}

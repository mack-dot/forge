include "Library.dfy"

// This file proves relations over the unchanged published UTF-8 functions.
// It defines no decoder and imports no axiom-bearing character wrapper.
module RefundUnicode {
  import B = Std.Unicode.Base
  import U = Std.Unicode.Utf8EncodingForm
  import S = Std.Collections.Seq

  lemma CharScalar(c: char)
    ensures (c as int as bv24) as int == c as int
    ensures c as int as bv24 <= 0x10ffff
    ensures c as int as bv24 < 0xd800 || 0xdfff < c as int as bv24
  {
    assert 0 <= c as int < 0x110000;
    assert c as int < 0xd800 || 0xe000 <= c as int;
    assert (c as int as bv24) as int == c as int;
  }

  function Scalar(c: char): B.ScalarValue
    ensures Scalar(c) as int == c as int
  {
    CharScalar(c);
    c as int as B.ScalarValue
  }

  lemma ScalarRoundTrip(v: B.ScalarValue)
    ensures U.DecodeMinimalWellFormedCodeUnitSubsequence(U.EncodeScalarValue(v)) == v
  {
    if v <= 0x7f {
    } else if v <= 0x7ff {
    } else if v <= 0xffff {
    } else {
    }
  }

  lemma ScalarInjective(a: B.ScalarValue, b: B.ScalarValue)
    ensures U.EncodeScalarValue(a) == U.EncodeScalarValue(b) ==> a == b
  {
    ScalarRoundTrip(a);
    ScalarRoundTrip(b);
  }
}

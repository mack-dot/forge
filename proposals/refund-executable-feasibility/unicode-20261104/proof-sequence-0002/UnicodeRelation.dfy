include "Library.dfy"

// This file proves relations over the unchanged published UTF-8 functions.
// It defines no decoder and imports no axiom-bearing character wrapper.
module ScalarCast {
  @IsolateAssertions
  @ResourceLimit("20e6")
  lemma Int24RoundTrip(n: nat)
    requires n < 0x1000000
    ensures (n as bv24) as int == n
  {
    assert n % 0x1000000 == n;
  }
}

module RefundUnicode {
  import B = Std.Unicode.Base
  import U = Std.Unicode.Utf8EncodingForm
  import S = Std.Collections.Seq
  import C = ScalarCast
  import W = Std.Wrappers

  @IsolateAssertions
  @ResourceLimit("20e6")
  lemma CharScalar(c: char)
    ensures (c as int as bv24) as int == c as int
    ensures c as int as bv24 <= 0x10ffff
    ensures c as int as bv24 < 0xd800 || 0xdfff < c as int as bv24
  {
    assert 0 <= c as int < 0x110000;
    assert c as int < 0xd800 || 0xe000 <= c as int;
    C.Int24RoundTrip(c as int);
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

  lemma {:induction false} EncodePartition(vs: seq<B.ScalarValue>)
    ensures U.PartitionCodeUnitSequenceChecked(U.EncodeScalarSequence(vs)) ==
      W.Success(S.Map(U.EncodeScalarValue, vs))
    decreases |vs|
  {
    reveal S.Map();
    if |vs| > 0 {
      EncodePartition(vs[1..]);
      var head: U.CodeUnitSeq := U.EncodeScalarValue(vs[0]);
      var tail: U.CodeUnitSeq := U.EncodeScalarSequence(vs[1..]);
      U.LemmaSplitPrefixMinimalWellFormedCodeUnitSubsequenceInvertsPrepend(head, tail);
      assert U.EncodeScalarSequence(vs) == head + tail;
      assert (head + tail)[|head|..] == tail;
    }
  }

  lemma SequenceRoundTrip(vs: seq<B.ScalarValue>)
    ensures U.DecodeCodeUnitSequence(U.EncodeScalarSequence(vs)) == vs
  {
    EncodePartition(vs);
    var parts := U.PartitionCodeUnitSequence(U.EncodeScalarSequence(vs));
    assert parts == S.Map(U.EncodeScalarValue, vs);
    var decoded := U.DecodeCodeUnitSequence(U.EncodeScalarSequence(vs));
    forall i | 0 <= i < |vs|
      ensures decoded[i] == vs[i]
    {
      ScalarRoundTrip(vs[i]);
      assert parts[i] == U.EncodeScalarValue(vs[i]);
    }
  }

  function Scalars(s: string): seq<B.ScalarValue> {
    S.Map(Scalar, s)
  }

  function Encoded(s: string): string {
    var bytes := U.EncodeScalarSequence(Scalars(s));
    seq(|bytes|, i requires 0 <= i < |bytes| => (bytes[i] as int) as char)
  }

  lemma EncodedIsBytes(s: string)
    ensures forall i | 0 <= i < |Encoded(s)| :: 0 <= Encoded(s)[i] as int < 256
  {
  }

  lemma EncodedInjective(s: string, t: string)
    ensures Encoded(s) == Encoded(t) ==> s == t
  {
    if Encoded(s) == Encoded(t) {
      var bs := U.EncodeScalarSequence(Scalars(s));
      var bt := U.EncodeScalarSequence(Scalars(t));
      assert bs == bt by {
        forall i | 0 <= i < |bs|
          ensures bs[i] == bt[i]
        {
          assert bs[i] as int == Encoded(s)[i] as int;
          assert bt[i] as int == Encoded(t)[i] as int;
        }
      }
      SequenceRoundTrip(Scalars(s));
      SequenceRoundTrip(Scalars(t));
      assert Scalars(s) == Scalars(t);
      forall i | 0 <= i < |s|
        ensures s[i] == t[i]
      {
        assert Scalars(s)[i] == Scalar(s[i]);
        assert Scalars(t)[i] == Scalar(t[i]);
        assert Scalar(s[i]) == Scalar(t[i]);
      }
    }
  }

  lemma EncodedEmpty(s: string)
    ensures Encoded(s) == "" <==> s == ""
  {
    reveal S.Map();
    assert Encoded("") == "";
    EncodedInjective(s, "");
  }
}

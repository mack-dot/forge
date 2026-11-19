// r-export (adversarial review of b-export-bridge), night shift 2026-11-19. A DRAFT. NOT gate evidence.
// Extra facts about the bridge. No assume, no axiom, no bodiless lemma.
include "SliceSafetyFromExport.dfy"

module RExtra {
  import opened SinkCore
  import opened SliceTheorem
  import opened SliceTheoremV2B
  import opened SliceFromExport
  import opened ExportedGen
  import L = LinkedRefund
  import EB = ExportBridge
  import U = RefundUnicode
  import SliceWitness

  const X1: FlatIn := FlatIn("ch_1", "rq_1", 100, 60, true, true, true, 40, "duplicate_charge")

  // A single-sided swap: the artifact swaps charge and request in the OUTPUTS only.
  function SwapOut(x: FlatIn): L.FlatTuple
  {
    var o := FlatSpecFn(x); (o.0, o.1, o.2, o.4, o.3, o.5)
  }

  // A double swap inside the artifact: read charge as request and request as charge, swap the outputs back.
  function DoubleSwap(x: FlatIn): L.FlatTuple
  {
    var o := FlatSpecFn(x.(chargeB := x.requestB, requestB := x.chargeB)); (o.0, o.1, o.2, o.4, o.3, o.5)
  }

  // R1. The single-sided swap does NOT meet A6x (a byte-string input with chargeB != requestB refutes it).
  lemma SwapOutFailsA6x()
    ensures !A6x_ArtifactMeetsExportedContractOnBytes(SwapOut)
  {
    assert ByteInputs(X1);
    assert !ExportedContract(X1, SwapOut(X1));
  }

  // R2. The single-sided swap gives a wrong Unflatten result on the witness inputs (FlatResultAgrees fails there).
  lemma SwapOutWrongUnflatten()
    ensures var x := FlatInputsOf(SliceWitness.W_PRE, SliceWitness.W_INTENT);
            var o := SwapOut(x);
            L.Unflatten(o.0, o.1, o.2, o.3, o.4, o.5) !=
              (L.Authorized(40, "duplicate_charge"), [L.Intent("ch_1", "rq_1", 40, "duplicate_charge")])
  {
    var x := FlatInputsOf(SliceWitness.W_PRE, SliceWitness.W_INTENT);
    U.EncodedEmpty("ch_1"); U.EncodedEmpty("rq_1"); U.SameReasons("duplicate_charge");
    L.DecodeEncoded("ch_1"); L.DecodeEncoded("rq_1");
    assert x.chargeB == U.Encoded("ch_1") && x.requestB == U.Encoded("rq_1");
    var o := SwapOut(x);
    assert o.0 && o.3 == x.requestB && o.4 == x.chargeB && o.5 == 1;
    assert L.Decode(o.3) == "rq_1";
  }

  // R3. The double swap inside the artifact is the SAME function as FlatSpecFn: clause 1 is symmetric in
  // chargeB and requestB. So a double swap is invisible because it changes nothing.
  lemma DoubleSwapIsFlatSpecFn(x: FlatIn)
    ensures DoubleSwap(x) == FlatSpecFn(x)
  {
  }

  // R4. Output strings: on byte-string inputs, any tuple that meets the exported contract has byte-string outputs.
  lemma ExportedForcesByteOutputs(x: FlatIn, o: L.FlatTuple)
    requires ByteInputs(x) && ExportedContract(x, o)
    ensures IsByteString(o.2) && IsByteString(o.3) && IsByteString(o.4)
  {
    EB.ExportedIffFlat(x, o);
  }

  // R5. Unbounded integers: the contract is stated on Dafny int. The largest allowed original authorizes, and an
  // original one above it rejects (no 64-bit wraparound on the Dafny side).
  lemma IntegerEdges()
    ensures ExportedContract(FlatIn("c", "r", 9223372036854775807, 9223372036854775807, true, true, true,
                                    9223372036854775807, "returned_item"),
                             (true, 9223372036854775807, "returned_item", "c", "r", 1))
    ensures ExportedContract(FlatIn("c", "r", 9223372036854775808, 0, true, true, true, 0, "returned_item"),
                             (false, 0, "", "", "", 0))
    ensures ExportedContract(FlatIn("c", "r", 5, 5, true, true, true, -1, "returned_item"),
                             (false, 0, "", "", "", 0))
    ensures ExportedContract(FlatIn("c", "r", 0, 0, true, true, true, 0, "returned_item"),
                             (true, 0, "returned_item", "c", "r", 1))
  {
  }
}

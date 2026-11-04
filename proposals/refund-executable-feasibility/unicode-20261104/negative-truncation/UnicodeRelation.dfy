module InvalidTruncation {
  method TruncationDoesNotPreserveIdentity() {
    var c: char := 'Ā';
    var narrowed := ((c as int) % 256) as char;
    assert narrowed == c; // Deliberately false. Must not be accepted as a bridge.
  }
}

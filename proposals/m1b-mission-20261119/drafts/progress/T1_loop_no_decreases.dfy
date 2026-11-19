// Control: a loop that the verifier cannot prove terminating, no decreases *.
method M(n: int) returns (r: int) { r := n; while r != 0 { r := r - 1; } }

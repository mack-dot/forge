// A function-by-method: the compiled method part halts on every input. Does it verify?
function F(x: int): int { x + 1 } by method { expect false; return x + 1; }
method Caller() returns (y: int) ensures y == 4 { y := F(3); }

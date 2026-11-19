// Can a compiled function body contain expect? (expected: no, parse/resolution error)
function F(x: int): int { expect x > 0; x }

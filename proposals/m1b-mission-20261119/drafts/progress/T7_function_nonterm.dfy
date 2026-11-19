// Control: a compiled function with no termination measure must be refused.
function F(x: int): int { F(x + 1) }

// Control of T5: without expect, a wrong method part must be refused.
function F(x: int): int { x + 1 } by method { return x + 2; }

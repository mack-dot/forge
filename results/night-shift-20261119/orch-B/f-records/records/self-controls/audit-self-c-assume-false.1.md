|Name|Compiled|Explicit Assumption|Extern|Issue|Mitigation|
|----|--------|-------------------|------|-----|----------|
| SinkCore.SelfControlAssumeFalse | False | False | False | Definition has `assume` statement in body. | Replace with `assert` and prove or add `{:axiom}`. |

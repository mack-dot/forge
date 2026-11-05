# Refund model resource-limit binding

CURRENT stage:none; M1 open; Stage12 unauthorized; `end_to_end=false`.
This result proves the exact published resource-limit calculation under recorded
register-equality premises. It does not prove that the full program fits.

`forge_refundResourceBindingTheory.recorded_config` proves that the compiler
maps abstract heap registers2/3/4 to target registers1/2/3. For every register
allocation oracle, the configuration supplies maximum heap cap9007199254740991.

`recorded_limits` proves the existing `get_stack_heap_limit` equation:

```text
get_stack_heap_limit 9007199254740991
  (496542679040w,496811114496w,497079549952w:word64)
= (33554384,16777216)
```

`recorded_read_limits` retains three explicit register-equality premises and
concludes that `read_limits arm8_config (set_oracle arm8_backend_config oracle)
mc ms` equals this pair. The published calculation accounts for its48-word
store area and two heap semispaces. These are model stack/heap word counts.
They do not prove the native allocation is sufficient for unbounded input.

The pointer values come from U283's saved capture, whose readback SHA256 is
`65d4d7575d530a025aa8cfb2425e4884b9bdca0562a94bf312a6dccb88a49862`.
Its file identity matches the committed capture manifest. Mapping the physical
state to `mc.target.get_reg` still requires the concrete/model state relation.

| Command/check | Actual exit | Result |
| --- | --- | --- |
| `run.py positive` | 1 | Python rendering consumed conjunction backslashes; parse failure preserved |
| `run.py positive-0002` | 0 | Three exact model theorems proved |
| `run.py repeat` | 0 | Same source; four exports identical |
| `run.py wrong-limit-0002` | 1 | Claimed heap limit+1 reduces to F |
| `run.py stale-midpoint-0002` | 1 | Midpoint+16 with stale result reduces to F |
| `import_audit.py` | 0 | Three exact statements; zero explicit hypotheses/tagged axioms; DISK_THM only |
| `readback.py` | 0 |338 closure nodes,1683 files,50 protected paths and exact capture/source binding |

Each negative case preserves the valid configuration check, then fails at
`recorded_limits`. Neither creates a complete export. The negative changes are
checked byte for byte against the positive source. No native mutant executes.

Proof source SHA256:
`8cfa0077f484ab557609c82b1908ab8f6cd464fa9aa7eac1f3db17dc5193d792`.
Theory data SHA256:
`40d07eeab9189f9e2bcc02f071454c2c927ef91ffd5734c66f1e1a380edf65a6`.
The four prior HOL foundation axioms remain visible. All seven inspected
upstream source files match the pinned CakeML Git objects. The exact expected
terms, commands, logs, file identities and closure are in `records/`.

This is a same-host reconstruction and fresh import with cached parent data.
It does not authenticate a producer or independently replay all upstream source.
No new semantics, axiom, verifier, protected policy or native artifact is added.
This obligation is separate from U290's stopped entry-layout proof.

The required stronger compiler theorem retains
`forall po. is_safe_for_space ... (stack_limit,heap_limit)`.
That condition is **NOT_ESTABLISHED** for the full refund input domain. Complete
installation, physical ARM state, FFI/OS, interference and native exit remain
open. No assumption is accepted by this result and no claim is admitted.

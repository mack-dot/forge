# W-static: static tests T1 and T5 on the executable file (condensed by Orchestrator A). Class: TESTED-UNPROVED.
Copy of the image: SHA-256 b8ed5ec2…7bb8 (never executed). All commands exit 0. Raw outputs: `raw/`; `RESULT.json`.
- T1 PASS: `__TEXT` initprot = maxprot = r-x; no segment writable and executable; header PIE; signature ad hoc,
  linker-signed, NO hardened runtime, no entitlements; links only libSystem (23 imports). Deviations: no hardened runtime
  (the kernel does not strip `DYLD_*`: A-LOADER stays a launcher duty); LC_MAIN points to C `_main`, not `cml_main`.
- T5 PASS: the proved code slice (file 16592..147028, 32,609 words, digest 3c67983c…) decodes completely (two
  disassemblers and a class decoder agree; no data word): 0 words name x18 or w18; 0 uses of SP; 0 system, PAC, BTI,
  exclusive, pair, `bl`, `blr`, `ret` instructions; `br` 553 times. Every class is in the CakeML encoder subset.
- FFI stubs: one `b` each (no link) and NOPs; they touch no register; six branch targets as recorded.
- Consequence for the processor-bit premises (by reading, not a theorem): the slice has no SP-based access, so the SP
  alignment premise of `NextStateARM8_erase` concerns no instruction of the slice; an in-HOL decode lemma is MISSING.
- Not shown: which words execute; run-time state; the processor; the loader; run-time page protections.

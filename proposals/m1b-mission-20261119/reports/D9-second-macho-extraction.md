# Step D9: a second extraction of the code and bitmap slices of the M1 executable, and the inventory of every range that no proof covers (Y9, Opus; the executable was not run)

Worker report, saved verbatim by the orchestrator from the worker's transcript (home and scratch paths replaced). It is model output. It is not evidence by itself: the orchestrator's checks are in `TRACKER.md`.

---

Y9 report (graph links V1 and V2). Nothing in the repository was changed. I did not execute the executable.

**Findings**
1. **The second extraction gives the same values.** The file has SHA-256 `b8ed5ec2…39007bb8` and 238,776 bytes. My parser is my own pure-Python `struct` code. It finds the slices from symbols, not from fixed numbers:
   - Code is `[cake_main, _cake_codebuffer_begin)`: file offset 16592, 130,436 bytes, SHA-256 `3c67983c…15deb`.
   - Bitmaps are `[cake_bitmaps, _cake_bitmaps_buffer_begin)`: file offset 180248, 20,248 bytes = 2,531 words, SHA-256 `68d3f080…6fb76`.
   - These equal the U389 values and the manifest draft exactly.
   - They also equal what the HOL constants claim: LENGTH code 130436, data 2531, code[0]=126, code[4]=222, data[0]=4, data[1]=16, the cml_main stub at 16384 (108 bytes), the 8-part layout lengths, and all 18 `refund_macho_fields` values.
   - The compiler output `refund.S` (compile-0001) is a third source. Its `.byte` code (130,436 bytes) and its 2,531 `.quad` bitmap words also equal the slices.
2. **The first tool does not find the slices itself.** I read `extract_macho.py` (SHA-256 `f7b11bfd…`) only after I had all my numbers (2026-11-19 01:12 EST). It hardcodes `code_off=0x40D0`, `code_len=130436`, `bm_off=180224+0x18` and `bm_words=2531`. The HOL ML reader also has fixed offsets (`cuts`). The offsets were checked before, but not derived from the file. My symbol-based derivation is the first one.
3. **The view from `otool -l` agrees.** 105 load-command, segment and section fields agree, with 0 differences. The defined symbols from `nm -m` agree (615 = 615, 0 differences). `dyld_info -fixups` lists the same 23 binds.
4. **Negative controls (one byte flipped in a copy):**
   - A flip in the code slice or the bitmap slice is detected by the slice hash. Only the slice that holds the byte changes.
   - A flip outside both slices is not detected by the slice comparison. I tried the GOT, `_main`, the `__data` padding, the string table, the signature and the cml_main stub.
   - My own recomputation of the CodeDirectory page hashes (58 pages, codeLimit 236800) and the whole-file hash do detect it.
   - The 5 padding bytes at the end of the signature (238771–238776) are detected by the whole-file hash only.
   - The ad hoc signature gives integrity only, not authenticity, because anyone can re-sign.
   - A GOT flip and a string-table flip also crashed my parser. That is an accidental detection, not a check.
5. **Inventory for V2 (file offsets):**
   - 0–1320: header and 18 load commands. 1320–16384: zeros.
   - 16384–16492: cml_main stub. 16492–16592: NOP padding and 6 FFI trampolines.
   - 147028–147456: the code buffer, which is 107 NOPs, not zeros. 147456–151552: zeros.
   - 151552–153800: the C run-time (`basis_ffi.c`: `_main`, `_cml_install`, `ffi*`, `.cold` paths).
   - 153800–154064: 22 stubs. 154064–154590: `__cstring`. 154592–154752: `__unwind_info`. Then zeros to 163840.
   - 163840–164024: `__got`, 23 binds, all to libSystem. 164024–180224: zeros.
   - 180224–180248: the heap, stack and stack-end slots (zero in the file; `_main` sets them).
   - 200496–212992: zeros.
   - 212992–238776: `__LINKEDIT` (chained fixups, exports trie, function starts, symtab, indirect symbols, strings, signature).
   - Dynamic libraries: `/usr/lib/libSystem.B.dylib` only, and dyld `/usr/lib/dyld`.
   - The 23 binds: `___assert_rtn ___clear_cache ___error ___stderrp _close _exit _exp _fprintf _fputs _fwrite _getenv _log _malloc _memmove _open _pow _read _snprintf _strerror _strtod _strtoull _vfprintf _write`. There are 0 rebases.
   - Entry path, from my disassembly with otool: dyld runs first. Then `LC_MAIN` entryoff 152900 starts `_main`. `_main` stores argc and argv, then calls `getenv("CML_HEAP_SIZE"/"CML_STACK_SIZE")` and `malloc`. It writes `cml_heap`, `cml_stack` and `cml_stackend`, then does `bl _cake_text_begin`, which is `_cml_main` at 0x100004000. The HOL run of 27 steps starts there.
6. **Who covers what today.** `refund_image_mem` binds all of 0–163840 as an ASSUMED memory premise. The stub and the trampolines are tied to it only by literal bytes. The other ranges have only the whole-file hash through the trusted ML reader and roundtrip. No proof gives them a meaning: the C run-time, the stubs, the GOT and binds, `__LINKEDIT`, dyld, libSystem, and `_main`'s choice of heap, stack and stack end.
   - `_main`'s results are the U388 conditions on e. Those, and the refuted case `header_on_bitmaps_refuted`, depend on what `malloc` returns and on environment variables, and are assumed.
   - What could cover these ranges: an in-HOL Mach-O parser for the load commands and binds; a model of `_main` from its instructions plus a `malloc` contract; or a static run-time without dyld (the B2c audit).
7. **A correction for a draft.** `CLOSURE_SPEC.md` (v) says "`__LINKEDIT` 200496–238776". That is wrong. 200496–212992 is zero padding inside the `__DATA` segment, and `__LINKEDIT` starts at 212992. I also noticed that `_cake_bitmaps_buffer_begin` = `_cake_bitmaps_buffer_end` = `_argc` = 0x100030F30. The bitmap buffer is empty and sits at the address of argc. Its effect is unknown.

**Limits.** My parser was written by the same model family, on the same machine, from format knowledge I remember (I did not read any specification document), and inside the same mission. It is not independent in the Q3c sense. A truly independent party would need:
- a different person or organisation, and a different tool or language (for example LIEF, or a reviewed in-HOL parser);
- a different machine and OS image;
- the file obtained by hash from a separate channel;
- the format checked against Apple's published headers (`loader.h`, `fixup-chains.h`, `cs_blobs.h`).

**Files written (all in `<session scratch folder>/m1b/Y9/`)**
- Scripts: `y9_macho.py`, `y9_extract.py`, `y9_vs_otool.py`, `y9_cdhash.py`, `y9_controls.py`, `y9_inventory.py`
- Results: `parse.json`, `extract_result.json`, `controls.json`, `inventory.txt`
- Tool outputs: `otool_l.txt`, `nm_m.txt`, `dyld_fixups.txt`, `dyld_deps.txt`, `codesign.txt`, `main_disasm.txt`

**Commands run (actual exits)**
- `shasum` (file): 0
- `y9_macho.py`: 0
- `y9_extract.py`: 0 (ALL_EQUAL true)
- `y9_vs_otool.py`: 1 the first time (my own parse bug); 0 after the fix
- `otool -l`: 0
- `nm -m`: 0
- `dyld_info -fixups`: 0
- `dyld_info -dependents`: 0
- `codesign -dv`: 0
- `y9_cdhash.py`: 0
- `y9_controls.py`: 0
- `y9_inventory.py`: 0
- `otool -tvV -p`: 0

**Not determined:** the semantics of the C run-time and of libSystem; the load slide; what `malloc` returns.

| step | status | evidence or blocker |
|---|---|---|
| 1 own parser | done | `y9_macho.py`, `parse.json` |
| 2 compare | equal | `extract_result.json`; otool 0 differences; refund.S equal |
| 3 controls | done | `controls.json`; slices detect in-slice flips only |
| 4 inventory | done | `inventory.txt`, `dyld_fixups.txt`, `main_disasm.txt` |
| 5 limits | stated | same model family and machine |

| link id | proposed class | evidence |
|---|---|---|
| V1 | MACHINE-CHECKED (HOL part); Q3c second extraction TESTED-UNPROVED, not independent | Y9 values equal; the first tool hardcodes its offsets |
| V2 | MISSING | full inventory; whole-file hash and CodeDirectory hashes only |

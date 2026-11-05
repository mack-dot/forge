"""Bind saved observations and standard nm output to an existing HOL predicate."""
import hashlib,json,re,struct,subprocess
from pathlib import Path
ROOT=Path('/Users/mackianni/forge');OUT=Path(__file__).resolve().parent
TC=ROOT/'.toolchain/experiments/refund-cakeml-20261104'
CAP=ROOT/'results/refund-entry-observation-2026-11-04/attempt-fullmap'
NATIVE=ROOT/'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(NATIVE)=='b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
saved=json.loads((CAP/'readback.json').read_text());assert saved['actual_exit']==0
assert saved['native_exit']==0 and saved['all_34_recorded_registers_unchanged_before_resume']
assert sha(CAP/'loaded-code.bin')=='3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb'
assert sha(CAP/'loaded-bitmaps.bin')=='68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76'
assert not (OUT/'inputs.json').exists()
argv=['/usr/bin/nm','-n',str(NATIVE)]
nm=subprocess.run(argv,capture_output=True,text=True)
(OUT/'nm.stdout').write_text(nm.stdout);(OUT/'nm.stderr').write_text(nm.stderr)
(OUT/'nm-command.json').write_text(json.dumps({'argv':argv,'actual_exit':nm.returncode,'native_sha256':sha(NATIVE)},indent=2)+'\n')
assert nm.returncode==0
symbols={name:int(addr,16) for addr,name in re.findall(r'^([0-9a-fA-F]+)\s+.*\s(cake_(?:main|exit|install|ffiread|ffiwrite|fficlose|ffiopen_in))$',nm.stdout,re.M)}
assert len(symbols)==7
pc=saved['registers']['pc'];slide=pc-symbols['cake_main']
addresses={name:address+slide for name,address in symbols.items()}
bm_begin,bm_end,data_end,cb_begin,cb_end=struct.unpack('<5Q',(CAP/'heap-header.bin').read_bytes())
heap_begin=saved['registers']['x1'];heap_end=saved['registers']['x3']
assert cb_begin==pc+len((CAP/'loaded-code.bin').read_bytes())
assert bm_end==bm_begin+len((CAP/'loaded-bitmaps.bin').read_bytes()) and data_end==bm_end
names=['read','write','close','open_in'];entries=[addresses['cake_ffi'+name] for name in names]
domain=f'(\\a:word64. ({pc} <= w2n a /\\ w2n a < {cb_end}) \\/ ({heap_begin} <= w2n a /\\ w2n a < {heap_end}) \\/ ({bm_begin} <= w2n a /\\ w2n a < {bm_end}))'
ffis='[ExtCall «read»;ExtCall «write»;ExtCall «close»;ExtCall «open_in»]'
for case in ['positive','wrong-ffi-slot','halt-in-domain']:
    dest=OUT/case;dest.mkdir(exist_ok=False)
    actual_entries=entries[:];actual_domain=domain
    if case=='wrong-ffi-slot':actual_entries[0],actual_entries[1]=actual_entries[1],actual_entries[0]
    if case=='halt-in-domain':actual_domain=f'({domain} UNION {{{addresses["cake_exit"]}w}})'
    config=f'(mc with <| prog_addresses := {actual_domain}; shared_addresses := {{}}; halt_pc := {addresses["cake_exit"]}w; install_pc := {addresses["cake_install"]}w; ffi_names := {ffis}; ffi_entry_pcs := ['+';'.join(str(a)+'w' for a in actual_entries)+'] |>)'
    body=f'''load "forge_refundArm8CompileTheory";
load "lab_to_targetProofTheory";
open preamble targetSemTheory;
val _ = OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_ENTRY_MODEL_OUT"));
val _ = new_theory "forge_refundEntryLayout";
val compiled_ffi_names = store_thm("compiled_ffi_names",
 ``forge_refundArm8Compile$ffis = ["read";"write";"close";"open_in"]``, EVAL_TAC);
val observed_mmio_index = store_thm("observed_mmio_index",
 ``mmio_pcs_min_index {ffis} = SOME 4``,
 MP_TAC (Q.SPECL [`[]`,`{ffis}`] lab_to_targetProofTheory.mmio_pcs_min_index_APPEND_thm) >> simp[]);
val required = ``start_pc_ok {config} ({pc}w:word64)``;
val _ = print "CHECKING_RECORDED_ENTRY_LAYOUT\\n";
val recorded_entry_layout = store_thm("recorded_entry_layout", required,
 simp[start_pc_ok_def,lab_to_targetTheory.ffi_offset_def,observed_mmio_index,GSYM NOT_LESS,IN_DEF] >>
 CONV_TAC(DEPTH_CONV(numLib.BOUNDED_FORALL_CONV EVAL)) >> EVAL_TAC);
val _ = List.app(fn th => let val (ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s => s="DISK_THM") ors then ()
 else raise Fail "Unexpected hypotheses, axioms or oracle tags" end)
 [compiled_ffi_names,observed_mmio_index,recorded_entry_layout];
val _ = export_theory();
val _ = print "ENTRY_LAYOUT_COMPLETE\\n";
val _ = OS.Process.exit OS.Process.success;
'''
    (dest/'proof.sml').write_text(body)
record={'actual_exit':0,'native_sha256':sha(NATIVE),'capture_readback_sha256':sha(CAP/'readback.json'),
        'header_sha256':sha(CAP/'heap-header.bin'),'observed_pc':pc,'file_symbols':symbols,
        'derived_slide':slide,'derived_entry_addresses':addresses,
        'candidate_domains':{'code_and_codebuffer':[pc,cb_end],'heap_stack':[heap_begin,heap_end],'bitmaps':[bm_begin,bm_end]},
        'ffi_order':names,'source_sha256':{case:sha(OUT/case/'proof.sml') for case in ['positive','wrong-ffi-slot','halt-in-domain']},
        'scope':'Recorded scalar addresses and a candidate projected domain, not complete installed state or physical loader/FFI refinement',
        'remaining_assumption':'Uniform relocation of the identified image symbols; actual relevant memory maps to the candidate projected domain',
        'end_to_end':False}
(OUT/'inputs.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record))

"""Render observed bytes as HOL constants; existing HOL semantics checks them."""
from pathlib import Path
import hashlib,json
ROOT=Path('/Users/mackianni/forge')
OUT=Path(__file__).resolve().parent
CAP=OUT/'capture-0001'
assert json.loads((OUT/'capture-readback.json').read_text())['actual_exit']==0
FIX=ROOT/'results/refund-native-audit-2026-11-04/attempt-0003/wire'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(FIX/'eligible_duplicate.stdin')=='7b450385073cc30d774749b240a8eb8252bfb9ba89b9af62d0f1e1435297c84f'
assert sha(FIX/'eligible_duplicate.stdout')=='629d44e9f09823060942f4b75007dcf87ddce9c505314a4b74f9ac19d9d84cee'

def chars(b): return '(MAP CHR ['+';'.join(str(x) for x in b)+'])'
def words(b): return '(['+';'.join(str(x)+'w' for x in b)+']:word8 list)'
def fs(i):
    inp=chars((FIX/'eligible_duplicate.stdin').read_bytes())
    output=chars((FIX/'eligible_duplicate.stdout').read_bytes()) if i==4 else '[]'
    stream='ns'
    for _ in range(4-i):stream='LCONS 4096 ('+stream+')'
    return ('(<| inode_tbl := [(UStream «stdin»,'+inp+');(UStream «stdout»,'+output+');(UStream «stderr»,[])]; '
      'files := []; infds := [(0,(UStream «stdin»,ReadMode,'+str(0 if i==0 else 62)+'));'
      '(1,(UStream «stdout»,WriteMode,'+str(64 if i==4 else 0)+'));(2,(UStream «stderr»,WriteMode,0))]; '
      'numchars := '+stream+'; maxFD := 1024 |>:IO_fs)')

for case in ['positive','altered-read-byte','wrong-write-descriptor']:
    dest=OUT/('model-'+case);dest.mkdir(exist_ok=False)
    lines=['load "basis_ffiTheory";','open preamble basis_ffiTheory fsFFITheory ffiTheory cfFFITypeTheory;',
      'val _ = OS.FileSys.chDir '+json.dumps(str(dest))+';',
      'val _ = new_theory "forge_refundObservedFFI";',
      'val _ = Globals.max_print_depth := 30;',
      'val checked = ref ([]:thm list);']
    for i in range(4):
        name='read' if i<3 else 'write'
        conf=(CAP/f'call-{i:02d}-conf-before.bin').read_bytes()
        before=(CAP/f'call-{i:02d}-data-before.bin').read_bytes()
        after=(CAP/f'call-{i:02d}-data-after.bin').read_bytes()
        if case=='altered-read-byte' and i==0:
            a=bytearray(after);a[4]^=1;after=bytes(a)
        if case=='wrong-write-descriptor' and i==3:conf=bytes(8)
        lines.extend([f'val expected_{i} = ``basis_ffi_oracle no_ext (ExtCall «{name}») (cl,{fs(i)}) {words(conf)} {words(before)} = Oracle_return (cl,{fs(i+1)}) {words(after)}``;',
          f'val _ = print "CHECKING_OBSERVED_FFI_{i}\\n";',
          f'val th_{i} = store_thm ("observed_ffi_{i}", expected_{i}, EVAL_TAC);',
          f'val _ = checked := th_{i} :: !checked;',
          f'val _ = print "OBSERVED_FFI_{i}_CHECKED\\n";'])
    lines.extend(['val _ = List.app (fn th => let val (ors,axs)=Tag.dest_tag (Thm.tag th) in',
      '  if null(hyp th) andalso null axs andalso List.all (fn x => x="DISK_THM") ors then ()',
      '  else raise Fail "Unexpected proof assumptions or oracle tags" end) (!checked);',
      'val _ = export_theory ();',
      'val _ = print "OBSERVED_FFI_MODEL_CHECK_COMPLETE\\n";',
      'val _ = OS.Process.exit OS.Process.success;'])
    (dest/'check.sml').write_text('\n'.join(lines)+'\n')
(OUT/'model-preparation.json').write_text(json.dumps({'scope':'Four captured calls checked against published basis_ffi_oracle; arbitrary unobserved numchars tail ns and command-line value cl','not_claimed':['universal C/POSIX refinement','full initial filesystem correspondence','physical liveness','full memory frame','executable theorem'],'frozen_stdin_sha256':sha(FIX/'eligible_duplicate.stdin'),'frozen_stdout_sha256':sha(FIX/'eligible_duplicate.stdout'),'source_hashes':{p.name:sha(p/'check.sml') for p in OUT.glob('model-*') if p.is_dir()},'end_to_end':False},indent=2)+'\n')
print('Prepared positive and two negative HOL checks')

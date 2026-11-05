"""Use existing HOL term constructors for the same complete word-list literals."""
import hashlib,json,re
from pathlib import Path
OUT=Path(__file__).resolve().parent
src=OUT/'model-positive-0002/check.sml'
original=src.read_text();original_lines=original.splitlines()
helper=['fun byte_terms xs = let',
 '  val terms = map (fn n => wordsSyntax.mk_wordii(n,8)) xs;',
 '  val term = listSyntax.mk_list(terms,wordsSyntax.mk_int_word_type 8);',
 '  val (roundtrip,ty) = listSyntax.dest_list term;',
 '  val numbers = map (Arbnum.toInt o #1 o wordsSyntax.dest_word) roundtrip;',
 '  val _ = if numbers=xs andalso ty=wordsSyntax.mk_int_word_type 8 then () else raise Fail "Byte term identity";',
 'in term end;']
base=[];count=0;sizes=[]
for line in original_lines:
 if line.startswith('val _ = OS.FileSys.chDir'):
  base.append('val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_OBSERVED_FFI_OUT"));');continue
 if line.startswith('val expected_'):
  definitions=[]
  def replace(m):
   global count
   values=[int(x[:-1]) for x in m.group(1).split(';') if x];name='captured_bytes_'+str(count);count+=1;sizes.append(len(values))
   definitions.append('val '+name+' = byte_terms ['+','.join(str(v) for v in values)+'];')
   return '^'+name
  changed=re.sub(r'\(\[([0-9w;]*)\]:word8 list\)',replace,line)
  assert len(definitions)==3
  base.extend(definitions);base.append(changed)
 else:base.append(line)
base[2:2]=helper
assert count==12
for case in ['positive-0003','constructor-diagnostic']:
 dest=OUT/('model-'+case);dest.mkdir(exist_ok=False)
 lines=base[:]
 if case=='constructor-diagnostic':
  lines=[l for l in lines if not l.startswith('val _ = checked :=')]
  for i in range(4):
   old='val th_'+str(i)+' = store_thm ("observed_ffi_'+str(i)+'", expected_'+str(i)+', EVAL_TAC);'
   new='val _ = if type_of expected_'+str(i)+' = bool then print "CONSTRUCTED_'+str(i)+'\\n" else raise Fail "Expected boolean equation";'
   assert old in lines;lines[lines.index(old)]=new
  lines=[l for l in lines if l!='val _ = export_theory ();']
  lines=[l.replace('OBSERVED_FFI_MODEL_CHECK_COMPLETE','CONSTRUCTOR_DIAGNOSTIC_COMPLETE') for l in lines]
 (dest/'check.sml').write_text('\n'.join(lines)+'\n')
record={'scope':'Preparation only; no semantic claim','original_source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'constructor_api':'wordsSyntax.mk_wordii + listSyntax.mk_list','complete_buffer_lengths':sizes,'equation_count':4,'all_scalar_filesystem_terms_unchanged':True,'new_axioms':False,'end_to_end':False}
(OUT/'constructor-preparation.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record))

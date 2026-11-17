"""Build the strengthened replay source from the published script lines plus explicit edits.
Usage: make_replay.py <out.sml> <case> [<case> ...]. The published file is read only."""
import sys, re, hashlib
PUB='/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/backend/proofs/lab_to_targetProofScript.sml'
raw=open(PUB,'rb').read()
assert hashlib.sha256(raw).hexdigest().startswith('6cfb4a5f'), 'published script changed'
L=raw.decode().split('\n')
def lines(a,b): return '\n'.join(L[a-1:b])
THM='compile_no_install_prefix'
SKELETON='''val say = say0 "%s";

Theorem %s:
  lab_step_closed Inv ==>
  !^s1 res (mc_conf: ('a,'state,'b) machine_config) s2 code2 labs t1 ms1.
     oracle_tie mc_conf ms1 s1 /\\
     (evaluate s1 = (res,s2)) /\\ (res <> Error) /\\
     encoder_correct mc_conf.target /\\
     state_rel (mc_conf,code2,labs,p) s1 t1 ms1 ==>
     Inv s1 /\\ code_layout_ok (:'a) code2 ==>
     no_install_prefix mc_conf s1.ffi s1.clock ms1
Proof
  strip_tac
  \\\\ HO_MATCH_MP_TAC labSemTheory.evaluate_ind \\\\ NTAC 2 STRIP_TAC
  \\\\ ONCE_REWRITE_TAC [labSemTheory.evaluate_def]
  \\\\ Cases_on `s1.clock = 0` \\\\ full_simp_tac(srw_ss())[]
  \\\\ REPEAT (Q.PAT_X_ASSUM `T` (K ALL_TAC)) \\\\ REPEAT STRIP_TAC
  THEN1 (qpat_assum `state_rel _ _ _ _` (mp_then Any mp_tac state_rel_no_install_prefix_layout) \\\\ simp[no_install_prefix_zero])
  \\\\ drule state_rel_ctx \\\\ strip_tac
  \\\\ Cases_on `asm_fetch s1` \\\\ full_simp_tac(srw_ss())[]
  \\\\ Cases_on `x` \\\\ full_simp_tac(srw_ss())[] \\\\ Cases_on `a` \\\\ full_simp_tac(srw_ss())[]
  \\\\ REPEAT (Q.PAT_X_ASSUM `T` (K ALL_TAC)) \\\\ full_simp_tac(srw_ss())[LET_DEF]
  THEN1 suspend "Asm"
  THEN1 suspend "ShareMemOp"
  THEN1 suspend "Jump"
  THEN1 suspend "JumpCmp"
  THEN1 suspend "Call"
  THEN1 suspend "LocValue"
  THEN1 suspend "CallFFI"
  THEN1 suspend "Install"
  THEN1 suspend "Halt"
QED
''' % (THM, THM)
def peel_spec(t):
    # Only the induction-hypothesis use: its first argument is the shifted machine configuration.
    t2=re.sub(r'FIRST_X_ASSUM \(MP_TAC o Q\.SPECL \[(\s*`shift_interfer)', r'FIRST_X_ASSUM (MP_TAC o peel o Q.SPECL [\1', t)
    t2=re.sub(r'FIRST_X_ASSUM \(qspecl_then \[(\s*`shift_interfer(?:.|\n)*?)\] mp_tac\)', r'FIRST_X_ASSUM (mp_tac o peel o Q.SPECL [\1])', t2)
    return t2
def bal_ok(a,b):
    t=lines(a,b); t=re.sub(r'\(\*.*?\*\)','',t,flags=re.S); t=re.sub(r'`[^`]*`','',t); t=re.sub(r'‘[^’]*’','',t)
    return t.count('(')==t.count(')')
def need(cond,msg):
    if not cond: raise SystemExit('edit site check failed: '+msg)
CASES={}
# Asm: Inst (7710-7760) and JumpReg (7761-7866). Endings are replaced; the hypothesis use gets peel.
inst=peel_spec(lines(7709,7754)); need(inst.count('peel')==1,'Inst IH')
jreg=peel_spec(lines(7761,7861)); need(jreg.count('peel')==1,'JumpReg IH')
CASES['Asm']=inst+'''
     \\\\ nip_finish [] [inc_pc_def,dec_clock_def,asm_inst_consts])
'''+jreg+'''
    \\\\ nip_finish [] [labSemTheory.upd_pc_def,dec_clock_def])
'''
jump=peel_spec(lines(8023,8094)); need(jump.count('peel')==1,'Jump IH')
CASES['Jump']=jump+'''
  \\\\ nip_finish [] [labSemTheory.upd_pc_def,dec_clock_def]
'''
CASES['Call']=lines(8255,8266)
CASES['Install']='''  say "Install"
  \\\\ qpat_x_assum `lab_step_closed _` (strip_assume_tac o REWRITE_RULE [lab_step_closed_def])
  \\\\ qpat_x_assum `!s i bs n. Inv s ==> _` drule
  \\\\ simp[]
'''
halt=lines(9322,9359); need('asm_step_IMP_evaluate_step_find_next' in halt,'Halt segment')
CASES['Halt']=halt+'''
  \\\\ FIRST_ASSUM (Q.SPEC_THEN `s1.clock`mp_tac) \\\\ srw_tac[][]
  \\\\ `mc_conf.target.get_pc ms2 = mc_conf.halt_pc` by
'''+lines(9365,9372)+'''
  \\\\ seg_split
  \\\\ `no_install_prefix (shift_interfer l' mc_conf) s1.ffi (s1.clock - 1) ms2` by
       (irule no_install_prefix_halt \\\\ fs[halt_ctx_def, shift_interfer_def])
  \\\\ nip_tail
'''
jc1=peel_spec(lines(8108,8185)); need(jc1.count('peel')==1,'JumpCmp taken IH')
jc2=peel_spec(lines(8196,8242)); need(jc2.count('peel')==1,'JumpCmp fallthrough IH')
CASES['JumpCmp']=jc1+'''
    \\\\ nip_finish [] [labSemTheory.upd_pc_def,dec_clock_def])
'''+jc2+'''
  \\\\ nip_finish [] [inc_pc_def,dec_clock_def]
'''
lv=peel_spec(lines(8270,8334)); need(lv.count('peel')==1,'LocValue IH')
CASES['LocValue']=lv+'''
  \\\\ nip_finish [lab_to_loc_def] [inc_pc_def,dec_clock_def,labSemTheory.upd_reg_def]
'''
ffi_pre=lines(8349,8501); need(bal_ok(8349,8500),'CallFFI prefix balance')
ffi_final_tail=lines(8507,8530)+'\n'+L[8530].rstrip()[:-1]
need(L[8530].rstrip().endswith('gvs[])'),'FFI_final end')
ffi_ret=lines(8532,8780)
CASES['CallFFI']=ffi_pre+'''
   ((* FFI_final *)
   sg `!n. FST (targetSem$evaluate (shift_interfer l' mc_conf) s1.ffi (SUC n) ms2) <> TimeOut`
   >- (gen_tac
       \\\\ once_rewrite_tac [targetSemTheory.evaluate_def]
       \\\\ simp[shift_interfer_def]
       \\\\ rpt (TOP_CASE_TAC \\\\ simp[])
       \\\\ fs[shift_interfer_def,read_ffi_bytearrays_def,read_ffi_bytearray_def]
       \\\\ gvs[]
       \\\\ dbg "FFI_FINAL_RESIDUE")
   \\\\ seg_split
   \\\\ qpat_x_assum `!n. FST _ <> TimeOut` (fn th => mp_tac (MATCH_MP final_nip th))
   \\\\ (impl_tac >- shift_tac)
   \\\\ disch_then (qspec_then `s1.clock - 1` assume_tac)
   \\\\ nip_tail)
'''+ffi_ret+'''
  \\\\ ih_extras []
  \\\\ qpat_x_assum `no_install_prefix _ _ _ _` (assume_tac o SIMP_RULE (srw_ss()) [])
  \\\\ dbg "FFI_RETURN"
  \\\\ sg `!n. targetSem$evaluate (shift_interfer l' mc_conf) s1.ffi (SUC n) ms2 =
              targetSem$evaluate (shift_interfer l' mc_conf with ffi_interfer := shift_seq 1 mc_conf.ffi_interfer) new_ffi n
                (mc_conf.ffi_interfer 0 (get_ffi_index mc_conf.ffi_names (ExtCall s),new_bytes,ms2))`
  >- (gen_tac
      \\\\ CONV_TAC (LAND_CONV (ONCE_REWRITE_CONV [targetSemTheory.evaluate_def]))
'''+lines(8787,8790)+'''
      \\\\ dbg "FFI_STEP"
      \\\\ TOP_CASE_TAC>>fs[]
      \\\\ TRY (TOP_CASE_TAC>>fs[])
      \\\\ TRY (TOP_CASE_TAC>>fs[])
      >- (pairarg_tac>>fs[apply_oracle_def])>>
'''+lines(8799,8806)+''')
  \\\\ seg_split
  \\\\ qpat_x_assum `!n. targetSem$evaluate _ _ (SUC n) _ = _` (fn th => mp_tac (MATCH_MP step_nip th))
  \\\\ (impl_tac >- shift_tac)
  \\\\ (impl_tac >- shift_tac)
  \\\\ (impl_tac >- shift_tac)
  \\\\ disch_then (qspec_then `s1.clock - 1` mp_tac)
  \\\\ (impl_tac >- first_assum ACCEPT_TAC)
  \\\\ strip_tac
  \\\\ `no_install_prefix (shift_interfer l' mc_conf) s1.ffi (s1.clock - 1) ms2` by
       (irule no_install_prefix_mono \\\\ qexists_tac `SUC (s1.clock - 1)` \\\\ simp[])
  \\\\ nip_tail
'''
CASES['ShareMemOp']='''  say "ShareMemOp (excluded by the invariant premise)"
  \\\\ qpat_x_assum `lab_step_closed _` (strip_assume_tac o REWRITE_RULE [lab_step_closed_def])
  \\\\ qpat_x_assum `!s m r ad bs n. Inv s ==> _` drule
  \\\\ simp[]
'''
out=[SKELETON, lines(8007,8020)+'\n']
for c in sys.argv[2:]:
    body=CASES[c]
    if 'RESUME' in body:
        pre,post=body.split('RESUME\n'); out.append(pre); body=post
    out.append('Resume %s[%s]:\n%s\nQED\nval _ = pr "CASE_PROVED %s";\n' % (THM,c,body.rstrip(),c))
open(sys.argv[1],'w').write('\n'.join(out))

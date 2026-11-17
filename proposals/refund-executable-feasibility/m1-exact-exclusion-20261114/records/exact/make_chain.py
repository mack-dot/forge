"""Build the exclusion chain source: published initial-state lemma replayed unchanged, then the
compile-level lemma replayed with the exclusion conclusion. The published file is read only."""
import sys, hashlib
PUB='/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/backend/proofs/lab_to_targetProofScript.sml'
raw=open(PUB,'rb').read()
assert hashlib.sha256(raw).hexdigest().startswith('6cfb4a5f'), 'published script changed'
L=raw.decode().split('\n')
def lines(a,b): return '\n'.join(L[a-1:b])
def need(c,m):
    if not c: raise SystemExit('edit site check failed: '+m)
need(L[10179].startswith('Theorem IMP_state_rel_make_init[local]'),'ISR start')
need(L[10561].startswith('Finalise IMP_state_rel_make_init'),'ISR end')
need(L[11059].startswith("Theorem semantics_compile_lemma'[local]"),'lemma start')
need(L[11088].strip()==') <> Fail ==>','lemma premise end')
need('match_mp_tac (GEN_ALL $ SRULE[] semantics_make_init)' in L[11112],'splice line')
need(L[11212].strip()=='QED','lemma QED')
def tail_fix(t):
    # One edit in the published tail: select the oracle hypothesis by pattern, not by position.
    old='last_x_assum(qspec_then`k` assume_tac)>>rfs[]>>'
    need(t.count(old)==1,'tail oracle step')
    t=t.replace(old,'qpat_x_assum `!k. _ (coracle k)` (qspec_then `k` assume_tac)>>rfs[]>>')
    # Second edit: the filter lemma is applied again at the end of the oracle conjunct.
    old2='    fs[GSYM ALL_EL_MAP]\n  )>>\n  qmatch_asmsub_rename_tac'
    need(t.count(old2)==1,'tail oracle end')
    t=t.replace(old2,'    fs[GSYM ALL_EL_MAP,no_share_mem_filter_skip]\n  )>>\n  qmatch_asmsub_rename_tac')
    # Third edit: close the semantics conjunct, whose paired lambda is not beta-reduced in this context.
    old3='  last_x_assum $ drule_then assume_tac >>'
    need(t.count(old3)==1,'tail positional step')
    return t.replace(old3,'  TRY (qpat_x_assum `semantics _ = Fail` mp_tac >> fs[ELIM_UNCURRY] >> NO_TAC) >>\n'+old3)
HEAD=open('chain-head.sml').read()
LOCALS=open('chain-locals.sml').read()
PRE=open('chain-pre.sml').read()
MID=open('chain-mid.sml').read()
SPLICE=open('chain-splice.sml').read()
TAIL=open('chain-tail.sml').read()
isr=lines(10180,10562).replace('Theorem IMP_state_rel_make_init[local]:','Theorem IMP_state_rel_make_init:',1)
stmt=lines(11061,11088)+'''
  ) <> Fail /\\
  lab_step_closed Inv /\\
  (!k. Inv (make_init mc_conf ffi t m dm sdm ms (filter_skip code)
              (compile_lab mc_conf.target.config) (mc_conf.target.get_pc ms + n2w (LENGTH bytes)) cbspace
              ((\\(a,b). (a,filter_skip b)) o coracle) with clock := k)) ==>
  !n. no_install_prefix mc_conf ffi n ms
'''
out=[HEAD, LOCALS, PRE, isr, MID, 'Theorem compile_install_exclusion:\n'+stmt+'Proof\n'+lines(11096,11112)+'\n'+SPLICE+'\n'+tail_fix(lines(11114,11212))+'\nQED\n', TAIL]
open(sys.argv[1],'w').write('\n'.join(out))

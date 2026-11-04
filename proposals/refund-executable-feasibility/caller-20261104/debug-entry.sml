val _ = print (Parse.thm_to_string (EVAL ``
let result = evaluate_decs ((FST (THE (prim_sem_env (ffi:unit ffi_state)))) with clock := 32)
 (refund_argument_env ffi «charge-A» «request-B» 100 60 T T T 40 «returned_item») refund_program
in case SND result of Rval env => INR (nsLookup env.v (Short «answer»)) | Rerr err => INL err``) ^ "\n");
OS.Process.exit OS.Process.success;

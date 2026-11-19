(* nv_controls.sml (worker W-nv). Read by BOTH mains after the lemmas (nv_prove.sml or nv_explore_calls.sml).
   NOT RUN. UNCHECKED. In proof mode a failed control is fatal (nv_control raises); in exploration it is printed. *)
val _ = pr "MARK CONTROLS";
(* the witness's envmc.ffi_interfer: the concrete witness of NV0 has envmc = refund_abs_env (ARB with prog_addresses := ..)
   (fs-r4-0001 proof.sml lines 84-85; refund_abs_env_def: ffi_interfer := refund_abs_ffi) *)
val _ =
  (let val fth0 = TH L_FIELDS
   in if null (hyp fth0)
      then pr ("CONTROL_WITNESS_FFI_INTERFER\n" ^ thm_to_string (ISPEC (rand (need "ENV0" ENV0_O)) fth0))
      else pr "CONTROL_WITNESS_FFI_INTERFER_UNAVAILABLE refund_abs_env_fields not closed"
   end)
  handle e => pr ("CONTROL_WITNESS_FFI_INTERFER_UNAVAILABLE " ^ trunc 300 (General.exnMessage e));
val _ = pr "NOTE the witness of NV1/NV1b is the (abstract) witness of the stored older theorem at slide 0x4000;";
val _ = pr "NOTE NV0 (optional) names one concrete witness; its ffi_interfer is printed above.";
(* NV1's body is the stored antecedent; the theorem (if stored) has exactly that statement *)
val _ = nv_control (aconv (snd (strip_exists NV1_STMT)) ANTE) "NV1 body aconv the antecedent of refund_profile_a_sl_shape";
val _ =
  (let val th = TH L_NV1
   in nv_control (null (hyp th) andalso aconv (concl th) NV1_STMT andalso aconv (snd (strip_exists (concl th))) ANTE)
        "stored NV1: no hypothesis, conclusion = statement, body aconv the stored antecedent"
   end)
  handle e => nv_control false ("NV1 theorem not available " ^ trunc 200 (General.exnMessage e));
val _ =
  (let val th = TH L_NV2
   in nv_control (null (hyp th) andalso aconv (concl th) NV2_STMT) "stored NV2: no hypothesis, conclusion = statement"
   end)
  handle e => nv_control false ("NV2 theorem not available " ^ trunc 200 (General.exnMessage e));
val _ = pr "NOTE NV2 does NOT state that a Terminate Success behaviour exists: refund_profile_a_sl_shape gives only";
val _ = pr "NOTE machine_sem .. SUBSET extend_with_resource_limit {Terminate Success io}; a resource stop is allowed.";
val _ = pr "PART_INFO nv_controls loaded";

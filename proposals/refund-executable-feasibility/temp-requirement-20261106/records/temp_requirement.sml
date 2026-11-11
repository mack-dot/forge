(* Dependency instrumentation only. Original SAT input and proof tools remain unchanged. *)
open HolKernel Parse boolLib bossLib;
val operation = ref "startup";
fun emit s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
fun beginOp name = (operation := name; emit ("OP_BEGIN " ^ name));
fun describe ex =
  (emit ("OP_EXCEPTION " ^ !operation);
   emit ("EXCEPTION " ^ Feedback.exn_to_string ex);
   (case ex of
      OS.SysErr (_, SOME code) => emit ("ERRNO " ^ OS.errorName code)
    | OS.SysErr (_, NONE) => emit "ERRNO NONE"
    | _ => emit "ERRNO NOT_SYSERR");
   (case PolyML.Exception.exceptionLocation ex of
      NONE => emit "EXCEPTION_LOCATION NONE"
    | SOME {file,startLine,startPosition,endLine,endPosition} =>
        emit ("EXCEPTION_LOCATION " ^ file ^ ":" ^ FixedInt.toString startLine ^
              ":" ^ FixedInt.toString startPosition ^ "-" ^
              FixedInt.toString endLine ^ ":" ^ FixedInt.toString endPosition)));
val _ =
  ((beginOp "private_scratch_read_write";
    let
      val path = valOf (OS.Process.getEnv "FORGE_PRIVATE_PROBE_FILE")
      val value = "FORGE environment scratch control\n"
      val output = TextIO.openOut path
      val _ = TextIO.output (output,value)
      val _ = TextIO.closeOut output
      val input = TextIO.openIn path
      val observed = TextIO.inputAll input
      val _ = TextIO.closeIn input
    in
      if observed = value then emit "PRIVATE_SCRATCH_READ_WRITE_PASS"
      else raise Fail "scratch read differs from write"
    end;
    beginOp "unchanged_term_CNF_initialization";
    let
      val p = Term.mk_var ("probe",bool)
      val tm = boolSyntax.mk_disj (p,boolSyntax.mk_neg p)
      val (cnfv,vc,lfn,clauses) = def_cnf.to_cnf false (boolSyntax.mk_neg tm)
    in
      emit ("DIAGNOSTIC_SAT_TERM " ^ Parse.term_to_string tm);
      emit ("CNF_VARIABLE_COUNT " ^ Int.toString vc);
      emit ("CNF_CLAUSE_COUNT " ^ Int.toString (Array.length clauses));
      if vc > 0 then emit "STANDARD_DIMACS_BRANCH_REQUIRES_TMPNAME"
      else raise Fail "No-variable branch; do not assume tmpName is needed"
    end;
    beginOp "OS.FileSys.tmpName";
    let val path = OS.FileSys.tmpName ()
    in emit ("TMPNAME_RETURNED " ^ path);
       emit "TEMP_CREATION_PASSED_UNEXPECTEDLY_PATH_PRESERVED"
    end;
    emit "TEMP_REQUIREMENT_DIAGNOSTIC_COMPLETE";
    OS.Process.exit OS.Process.success)
   handle ex => (describe ex; OS.Process.exit OS.Process.failure));

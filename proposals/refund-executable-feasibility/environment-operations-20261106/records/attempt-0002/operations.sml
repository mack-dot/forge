(* Environment observation only. No SAT call, theorem, export, or file creation. *)
val operation = ref "startup";
fun emit s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
fun probe name f =
  (operation := name; emit ("OP_BEGIN " ^ name); f (); emit ("OP_PASS " ^ name));
fun describe ex =
  (emit ("OP_EXCEPTION " ^ !operation);
   emit ("EXCEPTION " ^ General.exnMessage ex);
   (case ex of
      OS.SysErr (message, SOME code) => emit ("ERRNO " ^ OS.errorName code)
    | OS.SysErr (message, NONE) => emit "ERRNO NONE"
    | _ => emit "ERRNO NOT_SYSERR");
   (case PolyML.Exception.exceptionLocation ex of
      NONE => emit "EXCEPTION_LOCATION NONE"
    | SOME {file,startLine,startPosition,endLine,endPosition} =>
        emit ("EXCEPTION_LOCATION " ^ file ^ ":" ^ Int.toString startLine ^
              ":" ^ Int.toString startPosition ^ "-" ^
              Int.toString endLine ^ ":" ^ Int.toString endPosition)));
val _ =
  ((probe "read_original_diagnostic" (fn () =>
      let
        val path = valOf (OS.Process.getEnv "FORGE_DIAG_READ")
        val input = TextIO.openIn path
        val text = TextIO.inputN (input,64)
        val _ = TextIO.closeIn input
      in
        if size text = 64 then emit "READ_BYTES 64"
        else raise Fail "short diagnostic read"
      end);
    probe "allocate_65536_bytes" (fn () =>
      let val bytes = Word8Array.array (65536,0w0)
      in emit ("ALLOCATED_BYTES " ^ Int.toString (Word8Array.length bytes)) end);
    probe "temporary_directory_access_query_only" (fn () =>
      emit ("ACCESS_QUERY_VAR_TMP_WRITE " ^ Bool.toString
        (OS.FileSys.access ("/var/tmp",[OS.FileSys.A_WRITE]))));
    probe "polyml_system_true" (fn () =>
      let val status = OS.Process.system "/usr/bin/true"
      in
        emit ("SYSTEM_STATUS " ^ PolyML.makestring status);
        if OS.Process.isSuccess status then emit "SYSTEM_SUCCESS true"
        else raise Fail "system returned non-success"
      end);
    emit "ENVIRONMENT_OPERATIONS_COMPLETE";
    OS.Process.exit OS.Process.success)
   handle ex =>
     (describe ex; OS.Process.exit OS.Process.failure));

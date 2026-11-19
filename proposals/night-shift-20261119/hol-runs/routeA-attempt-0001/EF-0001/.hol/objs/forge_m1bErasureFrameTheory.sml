structure forge_m1bErasureFrameTheory :> forge_m1bErasureFrameTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_m1bErasureFrameTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_m1bErasureV2Theory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_m1bErasureFrame",
        hash = "e7b3ac5a10d9d1e8d50843d552858c10ae92432c",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_m1bErasureFrame" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op word2_cases _ = () val op word2_cases = TDB.find "word2_cases"
  fun op frame_write_X _ = ()
  val op frame_write_X = TDB.find "frame_write_X"
  fun op frame_write_SP _ = ()
  val op frame_write_SP = TDB.find "frame_write_SP"
  fun op frame_write_Mem _ = ()
  val op frame_write_Mem = TDB.find "frame_write_Mem"
  fun op frame_raise_exception _ = ()
  val op frame_raise_exception = TDB.find "frame_raise_exception"
  fun op frame_dfn_Unallocated _ = ()
  val op frame_dfn_Unallocated = TDB.find "frame_dfn_Unallocated"
  fun op frame_dfn_TestBitAndBranch _ = ()
  val op frame_dfn_TestBitAndBranch = TDB.find "frame_dfn_TestBitAndBranch"
  fun op frame_dfn_SystemInstruction _ = ()
  val op frame_dfn_SystemInstruction = TDB.find
    "frame_dfn_SystemInstruction"
  fun op frame_dfn_SupervisorCall _ = ()
  val op frame_dfn_SupervisorCall = TDB.find "frame_dfn_SupervisorCall"
  fun op frame_dfn_Shift _ = ()
  val op frame_dfn_Shift = TDB.find "frame_dfn_Shift"
  fun op frame_dfn_SecureMonitorCall _ = ()
  val op frame_dfn_SecureMonitorCall = TDB.find
    "frame_dfn_SecureMonitorCall"
  fun op frame_dfn_Reverse _ = ()
  val op frame_dfn_Reverse = TDB.find "frame_dfn_Reverse"
  fun op frame_dfn_Reserved _ = ()
  val op frame_dfn_Reserved = TDB.find "frame_dfn_Reserved"
  fun op frame_dfn_MultiplyHigh _ = ()
  val op frame_dfn_MultiplyHigh = TDB.find "frame_dfn_MultiplyHigh"
  fun op frame_dfn_MultiplyAddSubLong _ = ()
  val op frame_dfn_MultiplyAddSubLong = TDB.find
    "frame_dfn_MultiplyAddSubLong"
  fun op frame_dfn_MultiplyAddSub _ = ()
  val op frame_dfn_MultiplyAddSub = TDB.find "frame_dfn_MultiplyAddSub"
  fun op frame_dfn_MoveWide _ = ()
  val op frame_dfn_MoveWide = TDB.find "frame_dfn_MoveWide"
  fun op frame_dfn_MoveSystemRegister _ = ()
  val op frame_dfn_MoveSystemRegister = TDB.find
    "frame_dfn_MoveSystemRegister"
  fun op frame_dfn_MoveImmediateProcState _ = ()
  val op frame_dfn_MoveImmediateProcState = TDB.find
    "frame_dfn_MoveImmediateProcState"
  fun op frame_dfn_MemoryBarrier _ = ()
  val op frame_dfn_MemoryBarrier = TDB.find "frame_dfn_MemoryBarrier"
  fun op frame_dfn_LogicalShiftedRegister _ = ()
  val op frame_dfn_LogicalShiftedRegister = TDB.find
    "frame_dfn_LogicalShiftedRegister"
  fun op frame_dfn_LogicalImmediate _ = ()
  val op frame_dfn_LogicalImmediate = TDB.find "frame_dfn_LogicalImmediate"
  fun op frame_dfn_LoadStoreRegister _ = ()
  val op frame_dfn_LoadStoreRegister = TDB.find
    "frame_dfn_LoadStoreRegister"
  fun op frame_dfn_LoadStorePair _ = ()
  val op frame_dfn_LoadStorePair = TDB.find "frame_dfn_LoadStorePair"
  fun op frame_dfn_LoadStoreImmediate _ = ()
  val op frame_dfn_LoadStoreImmediate = TDB.find
    "frame_dfn_LoadStoreImmediate"
  fun op frame_dfn_LoadStoreAcquirePair _ = ()
  val op frame_dfn_LoadStoreAcquirePair = TDB.find
    "frame_dfn_LoadStoreAcquirePair"
  fun op frame_dfn_LoadStoreAcquire _ = ()
  val op frame_dfn_LoadStoreAcquire = TDB.find "frame_dfn_LoadStoreAcquire"
  fun op frame_dfn_LoadLiteral _ = ()
  val op frame_dfn_LoadLiteral = TDB.find "frame_dfn_LoadLiteral"
  fun op frame_dfn_HypervisorCall _ = ()
  val op frame_dfn_HypervisorCall = TDB.find "frame_dfn_HypervisorCall"
  fun op frame_dfn_Hint _ = ()
  val op frame_dfn_Hint = TDB.find "frame_dfn_Hint"
  fun op frame_dfn_Halt _ = ()
  val op frame_dfn_Halt = TDB.find "frame_dfn_Halt"
  fun op frame_dfn_ExtractRegister _ = ()
  val op frame_dfn_ExtractRegister = TDB.find "frame_dfn_ExtractRegister"
  fun op frame_dfn_ExceptionReturn _ = ()
  val op frame_dfn_ExceptionReturn = TDB.find "frame_dfn_ExceptionReturn"
  fun op frame_dfn_Division _ = ()
  val op frame_dfn_Division = TDB.find "frame_dfn_Division"
  fun op frame_dfn_DebugSwitch _ = ()
  val op frame_dfn_DebugSwitch = TDB.find "frame_dfn_DebugSwitch"
  fun op frame_dfn_DebugRestore _ = ()
  val op frame_dfn_DebugRestore = TDB.find "frame_dfn_DebugRestore"
  fun op frame_dfn_CountLeading _ = ()
  val op frame_dfn_CountLeading = TDB.find "frame_dfn_CountLeading"
  fun op frame_dfn_ConditionalSelect _ = ()
  val op frame_dfn_ConditionalSelect = TDB.find
    "frame_dfn_ConditionalSelect"
  fun op frame_dfn_ConditionalCompareRegister _ = ()
  val op frame_dfn_ConditionalCompareRegister = TDB.find
    "frame_dfn_ConditionalCompareRegister"
  fun op frame_dfn_ConditionalCompareImmediate _ = ()
  val op frame_dfn_ConditionalCompareImmediate = TDB.find
    "frame_dfn_ConditionalCompareImmediate"
  fun op frame_dfn_CompareAndBranch _ = ()
  val op frame_dfn_CompareAndBranch = TDB.find "frame_dfn_CompareAndBranch"
  fun op frame_dfn_ClearExclusive _ = ()
  val op frame_dfn_ClearExclusive = TDB.find "frame_dfn_ClearExclusive"
  fun op frame_dfn_CRC _ = ()
  val op frame_dfn_CRC = TDB.find "frame_dfn_CRC"
  fun op frame_dfn_Breakpoint _ = ()
  val op frame_dfn_Breakpoint = TDB.find "frame_dfn_Breakpoint"
  fun op frame_dfn_BranchRegister _ = ()
  val op frame_dfn_BranchRegister = TDB.find "frame_dfn_BranchRegister"
  fun op frame_dfn_BranchImmediate _ = ()
  val op frame_dfn_BranchImmediate = TDB.find "frame_dfn_BranchImmediate"
  fun op frame_dfn_BranchConditional _ = ()
  val op frame_dfn_BranchConditional = TDB.find
    "frame_dfn_BranchConditional"
  fun op frame_dfn_BitfieldMove _ = ()
  val op frame_dfn_BitfieldMove = TDB.find "frame_dfn_BitfieldMove"
  fun op frame_dfn_Address _ = ()
  val op frame_dfn_Address = TDB.find "frame_dfn_Address"
  fun op frame_dfn_AddSubShiftedRegister _ = ()
  val op frame_dfn_AddSubShiftedRegister = TDB.find
    "frame_dfn_AddSubShiftedRegister"
  fun op frame_dfn_AddSubImmediate _ = ()
  val op frame_dfn_AddSubImmediate = TDB.find "frame_dfn_AddSubImmediate"
  fun op frame_dfn_AddSubExtendRegister _ = ()
  val op frame_dfn_AddSubExtendRegister = TDB.find
    "frame_dfn_AddSubExtendRegister"
  fun op frame_dfn_AddSubCarry _ = ()
  val op frame_dfn_AddSubCarry = TDB.find "frame_dfn_AddSubCarry"
  fun op frame_SetTheFlags _ = ()
  val op frame_SetTheFlags = TDB.find "frame_SetTheFlags"
  fun op frame_Run _ = () val op frame_Run = TDB.find "frame_Run"
  fun op frame_Mem _ = () val op frame_Mem = TDB.find "frame_Mem"
  fun op frame_LoadStoreSingle _ = ()
  val op frame_LoadStoreSingle = TDB.find "frame_LoadStoreSingle"
  fun op frame_Hint_Branch _ = ()
  val op frame_Hint_Branch = TDB.find "frame_Hint_Branch"
  fun op frame_Fetch _ = () val op frame_Fetch = TDB.find "frame_Fetch"
  fun op frame_CheckSPAlignment _ = ()
  val op frame_CheckSPAlignment = TDB.find "frame_CheckSPAlignment"
  fun op frame_CheckAlignment _ = ()
  val op frame_CheckAlignment = TDB.find "frame_CheckAlignment"
  fun op frame_BranchTo _ = ()
  val op frame_BranchTo = TDB.find "frame_BranchTo"
  fun op W_nonvacuous _ = () val op W_nonvacuous = TDB.find "W_nonvacuous"
  fun op Next_frame_all _ = ()
  val op Next_frame_all = TDB.find "Next_frame_all"
  fun op Next_frame _ = () val op Next_frame = TDB.find "Next_frame"
  fun op NextStateARM8_frame _ = ()
  val op NextStateARM8_frame = TDB.find "NextStateARM8_frame"
  fun op Mem_state _ = () val op Mem_state = TDB.find "Mem_state"
  fun op FOR_snd_const _ = ()
  val op FOR_snd_const = TDB.find "FOR_snd_const"
  fun op FOR_proj _ = () val op FOR_proj = TDB.find "FOR_proj"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_m1bErasureFrame"

end

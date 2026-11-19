structure forge_m1bEraseStepTheory :> forge_m1bEraseStepTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_m1bEraseStepTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_m1bErasureFrameTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_m1bEraseStep",
        hash = "a8c5456640f88d36e31ab032154b7a3295d9a641",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_m1bEraseStep" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op writeX_PC _ = () val op writeX_PC = TDB.find "writeX_PC"
  fun op fupd_PC_id _ = () val op fupd_PC_id = TDB.find "fupd_PC_id"
  fun op erase_write_X _ = ()
  val op erase_write_X = TDB.find "erase_write_X"
  fun op erase_write_SP _ = ()
  val op erase_write_SP = TDB.find "erase_write_SP"
  fun op erase_write_Mem _ = ()
  val op erase_write_Mem = TDB.find "erase_write_Mem"
  fun op erase_upds _ = () val op erase_upds = TDB.find "erase_upds"
  fun op erase_reads _ = () val op erase_reads = TDB.find "erase_reads"
  fun op erase_raise_exception _ = ()
  val op erase_raise_exception = TDB.find "erase_raise_exception"
  fun op erase_dfn_Unallocated _ = ()
  val op erase_dfn_Unallocated = TDB.find "erase_dfn_Unallocated"
  fun op erase_dfn_SystemInstruction _ = ()
  val op erase_dfn_SystemInstruction = TDB.find
    "erase_dfn_SystemInstruction"
  fun op erase_dfn_SupervisorCall _ = ()
  val op erase_dfn_SupervisorCall = TDB.find "erase_dfn_SupervisorCall"
  fun op erase_dfn_Shift _ = ()
  val op erase_dfn_Shift = TDB.find "erase_dfn_Shift"
  fun op erase_dfn_SecureMonitorCall _ = ()
  val op erase_dfn_SecureMonitorCall = TDB.find
    "erase_dfn_SecureMonitorCall"
  fun op erase_dfn_Reverse _ = ()
  val op erase_dfn_Reverse = TDB.find "erase_dfn_Reverse"
  fun op erase_dfn_Reserved _ = ()
  val op erase_dfn_Reserved = TDB.find "erase_dfn_Reserved"
  fun op erase_dfn_MultiplyHigh _ = ()
  val op erase_dfn_MultiplyHigh = TDB.find "erase_dfn_MultiplyHigh"
  fun op erase_dfn_MultiplyAddSubLong _ = ()
  val op erase_dfn_MultiplyAddSubLong = TDB.find
    "erase_dfn_MultiplyAddSubLong"
  fun op erase_dfn_MultiplyAddSub _ = ()
  val op erase_dfn_MultiplyAddSub = TDB.find "erase_dfn_MultiplyAddSub"
  fun op erase_dfn_MoveWide _ = ()
  val op erase_dfn_MoveWide = TDB.find "erase_dfn_MoveWide"
  fun op erase_dfn_MoveSystemRegister _ = ()
  val op erase_dfn_MoveSystemRegister = TDB.find
    "erase_dfn_MoveSystemRegister"
  fun op erase_dfn_MoveImmediateProcState _ = ()
  val op erase_dfn_MoveImmediateProcState = TDB.find
    "erase_dfn_MoveImmediateProcState"
  fun op erase_dfn_MemoryBarrier _ = ()
  val op erase_dfn_MemoryBarrier = TDB.find "erase_dfn_MemoryBarrier"
  fun op erase_dfn_LogicalShiftedRegister _ = ()
  val op erase_dfn_LogicalShiftedRegister = TDB.find
    "erase_dfn_LogicalShiftedRegister"
  fun op erase_dfn_LogicalImmediate _ = ()
  val op erase_dfn_LogicalImmediate = TDB.find "erase_dfn_LogicalImmediate"
  fun op erase_dfn_LoadStoreRegister _ = ()
  val op erase_dfn_LoadStoreRegister = TDB.find
    "erase_dfn_LoadStoreRegister"
  fun op erase_dfn_LoadStorePair _ = ()
  val op erase_dfn_LoadStorePair = TDB.find "erase_dfn_LoadStorePair"
  fun op erase_dfn_LoadStoreImmediate _ = ()
  val op erase_dfn_LoadStoreImmediate = TDB.find
    "erase_dfn_LoadStoreImmediate"
  fun op erase_dfn_LoadStoreAcquirePair _ = ()
  val op erase_dfn_LoadStoreAcquirePair = TDB.find
    "erase_dfn_LoadStoreAcquirePair"
  fun op erase_dfn_LoadStoreAcquire _ = ()
  val op erase_dfn_LoadStoreAcquire = TDB.find "erase_dfn_LoadStoreAcquire"
  fun op erase_dfn_LoadLiteral _ = ()
  val op erase_dfn_LoadLiteral = TDB.find "erase_dfn_LoadLiteral"
  fun op erase_dfn_HypervisorCall _ = ()
  val op erase_dfn_HypervisorCall = TDB.find "erase_dfn_HypervisorCall"
  fun op erase_dfn_Hint _ = ()
  val op erase_dfn_Hint = TDB.find "erase_dfn_Hint"
  fun op erase_dfn_Halt _ = ()
  val op erase_dfn_Halt = TDB.find "erase_dfn_Halt"
  fun op erase_dfn_ExtractRegister _ = ()
  val op erase_dfn_ExtractRegister = TDB.find "erase_dfn_ExtractRegister"
  fun op erase_dfn_ExceptionReturn _ = ()
  val op erase_dfn_ExceptionReturn = TDB.find "erase_dfn_ExceptionReturn"
  fun op erase_dfn_Division _ = ()
  val op erase_dfn_Division = TDB.find "erase_dfn_Division"
  fun op erase_dfn_DebugSwitch _ = ()
  val op erase_dfn_DebugSwitch = TDB.find "erase_dfn_DebugSwitch"
  fun op erase_dfn_DebugRestore _ = ()
  val op erase_dfn_DebugRestore = TDB.find "erase_dfn_DebugRestore"
  fun op erase_dfn_CountLeading _ = ()
  val op erase_dfn_CountLeading = TDB.find "erase_dfn_CountLeading"
  fun op erase_dfn_ConditionalSelect _ = ()
  val op erase_dfn_ConditionalSelect = TDB.find
    "erase_dfn_ConditionalSelect"
  fun op erase_dfn_ConditionalCompareRegister _ = ()
  val op erase_dfn_ConditionalCompareRegister = TDB.find
    "erase_dfn_ConditionalCompareRegister"
  fun op erase_dfn_ConditionalCompareImmediate _ = ()
  val op erase_dfn_ConditionalCompareImmediate = TDB.find
    "erase_dfn_ConditionalCompareImmediate"
  fun op erase_dfn_ClearExclusive _ = ()
  val op erase_dfn_ClearExclusive = TDB.find "erase_dfn_ClearExclusive"
  fun op erase_dfn_CRC _ = ()
  val op erase_dfn_CRC = TDB.find "erase_dfn_CRC"
  fun op erase_dfn_Breakpoint _ = ()
  val op erase_dfn_Breakpoint = TDB.find "erase_dfn_Breakpoint"
  fun op erase_dfn_BitfieldMove _ = ()
  val op erase_dfn_BitfieldMove = TDB.find "erase_dfn_BitfieldMove"
  fun op erase_dfn_Address _ = ()
  val op erase_dfn_Address = TDB.find "erase_dfn_Address"
  fun op erase_dfn_AddSubShiftedRegister _ = ()
  val op erase_dfn_AddSubShiftedRegister = TDB.find
    "erase_dfn_AddSubShiftedRegister"
  fun op erase_dfn_AddSubImmediate _ = ()
  val op erase_dfn_AddSubImmediate = TDB.find "erase_dfn_AddSubImmediate"
  fun op erase_dfn_AddSubExtendRegister _ = ()
  val op erase_dfn_AddSubExtendRegister = TDB.find
    "erase_dfn_AddSubExtendRegister"
  fun op erase_dfn_AddSubCarry _ = ()
  val op erase_dfn_AddSubCarry = TDB.find "erase_dfn_AddSubCarry"
  fun op erase_X _ = () val op erase_X = TDB.find "erase_X"
  fun op erase_TranslationRegime _ = ()
  val op erase_TranslationRegime = TDB.find "erase_TranslationRegime"
  fun op erase_ShiftReg _ = ()
  val op erase_ShiftReg = TDB.find "erase_ShiftReg"
  fun op erase_SetTheFlags _ = ()
  val op erase_SetTheFlags = TDB.find "erase_SetTheFlags"
  fun op erase_SP _ = () val op erase_SP = TDB.find "erase_SP"
  fun op erase_Mem _ = () val op erase_Mem = TDB.find "erase_Mem"
  fun op erase_LoadStoreSingle _ = ()
  val op erase_LoadStoreSingle = TDB.find "erase_LoadStoreSingle"
  fun op erase_Hint_Branch _ = ()
  val op erase_Hint_Branch = TDB.find "erase_Hint_Branch"
  fun op erase_Fetch _ = () val op erase_Fetch = TDB.find "erase_Fetch"
  fun op erase_ExtendReg _ = ()
  val op erase_ExtendReg = TDB.find "erase_ExtendReg"
  fun op erase_ConditionHolds _ = ()
  val op erase_ConditionHolds = TDB.find "erase_ConditionHolds"
  fun op erase_CheckAlignment _ = ()
  val op erase_CheckAlignment = TDB.find "erase_CheckAlignment"
  fun op erase_BigEndian _ = ()
  val op erase_BigEndian = TDB.find "erase_BigEndian"
  fun op W_nonvacuous _ = () val op W_nonvacuous = TDB.find "W_nonvacuous"
  fun op U6_refund_end_state_erase_identity _ = ()
  val op U6_refund_end_state_erase_identity = TDB.find
    "U6_refund_end_state_erase_identity"
  fun op U5_erase_identity _ = ()
  val op U5_erase_identity = TDB.find "U5_erase_identity"
  fun op U4_next_pc_from_code_invariant _ = ()
  val op U4_next_pc_from_code_invariant = TDB.find
    "U4_next_pc_from_code_invariant"
  fun op U3_mem_dm_untagged _ = ()
  val op U3_mem_dm_untagged = TDB.find "U3_mem_dm_untagged"
  fun op U2_code_dm_untagged _ = ()
  val op U2_code_dm_untagged = TDB.find "U2_code_dm_untagged"
  fun op U1_untagged_iff _ = ()
  val op U1_untagged_iff = TDB.find "U1_untagged_iff"
  fun op SCTLR_reads _ = () val op SCTLR_reads = TDB.find "SCTLR_reads"
  fun op Run_pc _ = () val op Run_pc = TDB.find "Run_pc"
  fun op Run_erase_pc _ = () val op Run_erase_pc = TDB.find "Run_erase_pc"
  fun op Next_pc _ = () val op Next_pc = TDB.find "Next_pc"
  fun op Next_erase_sp _ = ()
  val op Next_erase_sp = TDB.find "Next_erase_sp"
  fun op Next_erase_same_pc _ = ()
  val op Next_erase_same_pc = TDB.find "Next_erase_same_pc"
  fun op Next_erase_pc _ = ()
  val op Next_erase_pc = TDB.find "Next_erase_pc"
  fun op Next_erase_exception _ = ()
  val op Next_erase_exception = TDB.find "Next_erase_exception"
  fun op Next_alt _ = () val op Next_alt = TDB.find "Next_alt"
  fun op NextStateARM8_erase _ = ()
  val op NextStateARM8_erase = TDB.find "NextStateARM8_erase"
  fun op NX_pc _ = () val op NX_pc = TDB.find "NX_pc"
  fun op NX_erase _ = () val op NX_erase = TDB.find "NX_erase"
  fun op NX_def _ = () val op NX_def = TDB.find "NX_def"
  fun op Mem_state _ = () val op Mem_state = TDB.find "Mem_state"
  fun op Fetch_keep _ = () val op Fetch_keep = TDB.find "Fetch_keep"
  fun op FOR_snd_const _ = ()
  val op FOR_snd_const = TDB.find "FOR_snd_const"
  fun op FOR_proj _ = () val op FOR_proj = TDB.find "FOR_proj"
  fun op FOR_pair_erase _ = ()
  val op FOR_pair_erase = TDB.find "FOR_pair_erase"
  fun op FOR_erase _ = () val op FOR_erase = TDB.find "FOR_erase"
  fun op BranchRegister_erase_untagged _ = ()
  val op BranchRegister_erase_untagged = TDB.find
    "BranchRegister_erase_untagged"
  fun op BranchImmediate_erase_untagged _ = ()
  val op BranchImmediate_erase_untagged = TDB.find
    "BranchImmediate_erase_untagged"
  fun op B2_dfn_TestBitAndBranch _ = ()
  val op B2_dfn_TestBitAndBranch = TDB.find "B2_dfn_TestBitAndBranch"
  fun op B2_dfn_CompareAndBranch _ = ()
  val op B2_dfn_CompareAndBranch = TDB.find "B2_dfn_CompareAndBranch"
  fun op B2_dfn_BranchRegister _ = ()
  val op B2_dfn_BranchRegister = TDB.find "B2_dfn_BranchRegister"
  fun op B2_dfn_BranchImmediate _ = ()
  val op B2_dfn_BranchImmediate = TDB.find "B2_dfn_BranchImmediate"
  fun op B2_dfn_BranchConditional _ = ()
  val op B2_dfn_BranchConditional = TDB.find "B2_dfn_BranchConditional"
  fun op B1_dfn_TestBitAndBranch _ = ()
  val op B1_dfn_TestBitAndBranch = TDB.find "B1_dfn_TestBitAndBranch"
  fun op B1_dfn_CompareAndBranch _ = ()
  val op B1_dfn_CompareAndBranch = TDB.find "B1_dfn_CompareAndBranch"
  fun op B1_dfn_BranchRegister _ = ()
  val op B1_dfn_BranchRegister = TDB.find "B1_dfn_BranchRegister"
  fun op B1_dfn_BranchImmediate _ = ()
  val op B1_dfn_BranchImmediate = TDB.find "B1_dfn_BranchImmediate"
  fun op B1_dfn_BranchConditional _ = ()
  val op B1_dfn_BranchConditional = TDB.find "B1_dfn_BranchConditional"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_m1bEraseStep"

end

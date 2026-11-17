structure forge_refundLoaderMemoryTheory :> forge_refundLoaderMemoryTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundLoaderMemoryTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundImageTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundLoaderMemory",
        hash = "91aa21f870b1ceaf50a51495740d026ea4602795",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundLoaderMemory" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_loader_startup _ = ()
  val op refund_loader_startup = TDB.find "refund_loader_startup"
  fun op refund_image_preserved _ = ()
  val op refund_image_preserved = TDB.find "refund_image_preserved"
  fun op refund_image_bitmap_clause _ = ()
  val op refund_image_bitmap_clause = TDB.find "refund_image_bitmap_clause"
  fun op refund_entry_pre_def _ = ()
  val op refund_entry_pre_def = TDB.find "refund_entry_pre_def"
  fun op refund_entry_pre_IMP_cml_main_pre _ = ()
  val op refund_entry_pre_IMP_cml_main_pre = TDB.find
    "refund_entry_pre_IMP_cml_main_pre"
  fun op refund_bitmaps_dm_def _ = ()
  val op refund_bitmaps_dm_def = TDB.find "refund_bitmaps_dm_def"
  fun op refund_bitmaps_dm_closed _ = ()
  val op refund_bitmaps_dm_closed = TDB.find "refund_bitmaps_dm_closed"
  fun op refund_bitmaps_dm_aligned _ = ()
  val op refund_bitmaps_dm_aligned = TDB.find "refund_bitmaps_dm_aligned"
  fun op header_on_bitmaps_refuted _ = ()
  val op header_on_bitmaps_refuted = TDB.find "header_on_bitmaps_refuted"
  fun op code_wrong_offset_rejected _ = ()
  val op code_wrong_offset_rejected = TDB.find "code_wrong_offset_rejected"
  fun op code_overlap_rejected _ = ()
  val op code_overlap_rejected = TDB.find "code_overlap_rejected"
  fun op code_loaded_from_memory _ = ()
  val op code_loaded_from_memory = TDB.find "code_loaded_from_memory"
  fun op code_byte_change_rejected _ = ()
  val op code_byte_change_rejected = TDB.find "code_byte_change_rejected"
  fun op bitmap_wrong_offset_rejected _ = ()
  val op bitmap_wrong_offset_rejected = TDB.find
    "bitmap_wrong_offset_rejected"
  fun op bitmap_word_change_rejected _ = ()
  val op bitmap_word_change_rejected = TDB.find
    "bitmap_word_change_rejected"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundLoaderMemory"

end

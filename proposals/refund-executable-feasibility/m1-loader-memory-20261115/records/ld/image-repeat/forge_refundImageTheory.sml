structure forge_refundImageTheory :> forge_refundImageTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundImageTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_loaderMemLemmasTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundImage",
        hash = "85de34e86c31b0923aed448a5686121298ed727a",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundImage" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_macho_fields _ = ()
  val op refund_macho_fields = TDB.find "refund_macho_fields"
  fun op refund_image_mem_def _ = ()
  val op refund_image_mem_def = TDB.find "refund_image_mem_def"
  fun op refund_image_code _ = ()
  val op refund_image_code = TDB.find "refund_image_code"
  fun op refund_image_cml_main _ = ()
  val op refund_image_cml_main = TDB.find "refund_image_cml_main"
  fun op refund_image_bitmaps _ = ()
  val op refund_image_bitmaps = TDB.find "refund_image_bitmaps"
  fun op refund_file_text_memory _ = ()
  val op refund_file_text_memory = TDB.find "refund_file_text_memory"
  fun op refund_file_text_length _ = ()
  val op refund_file_text_length = TDB.find "refund_file_text_length"
  fun op refund_file_length _ = ()
  val op refund_file_length = TDB.find "refund_file_length"
  fun op refund_file_def _ = ()
  val op refund_file_def = TDB.find "refund_file_def"
  fun op refund_file_code _ = ()
  val op refund_file_code = TDB.find "refund_file_code"
  fun op refund_file_cml_main _ = ()
  val op refund_file_cml_main = TDB.find "refund_file_cml_main"
  fun op refund_file_bitmaps _ = ()
  val op refund_file_bitmaps = TDB.find "refund_file_bitmaps"
  fun op refund_file_bitmap_length _ = ()
  val op refund_file_bitmap_length = TDB.find "refund_file_bitmap_length"
  fun op refund_code_data_samples _ = ()
  val op refund_code_data_samples = TDB.find "refund_code_data_samples"
  fun op le_num_def _ = () val op le_num_def = TDB.find "le_num_def"
  fun op layout_slices _ = ()
  val op layout_slices = TDB.find "layout_slices"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundImage"

end

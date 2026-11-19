structure forge_refundExportedRenderTheory :> forge_refundExportedRenderTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundExportedRenderTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundExportedContractTheory forge_refundWireProgTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundExportedRender",
        hash = "7508760a591d12608d3bde88de3ccbd2891489d2",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundExportedRender" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op exported_contract_on_rendered_output _ = ()
  val op exported_contract_on_rendered_output = TDB.find
    "exported_contract_on_rendered_output"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundExportedRender"

end

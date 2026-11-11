val _ = PolyML.SaveState.loadHierarchy ["/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol.state0", "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/src/num/termination/numheap", "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol.state", "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap"];
val _ = print ("LOADED_MODULES " ^ String.concatWith "," (Meta.loaded ()) ^ "\n");
val _ = holpathdb.fold (fn {vname,path} => fn () => print ("PATH_MAPPING " ^ vname ^ " " ^ path ^ "\n")) ();
val _ = print ("LOAD_PATH " ^ String.concatWith "," (!Meta.loadPath) ^ "\n");
val _ = print "METADATA_INSPECTION_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

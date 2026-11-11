fun inspect path =
  (print ("STATE " ^ path ^ "\n");
   case PolyML.SaveState.showParent path of
       NONE => print "PARENT NONE\n"
     | SOME parent => (print ("PARENT " ^ parent ^ "\n"); inspect parent));
val _ = inspect "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/misc/cakeml-heap";
val _ = print "PARENT_INSPECTION_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;

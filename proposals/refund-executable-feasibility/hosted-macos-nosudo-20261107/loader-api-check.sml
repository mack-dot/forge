val _ = PolyML.SaveState.loadHierarchy ["/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol.state0", "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/src/num/termination/numheap", "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/bin/hol.state", "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/examples/l3-machine-code/l3-heap", "/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/HOL/examples/l3-machine-code/arm8/step/arm8-heap"];
val _ = print ("LOADER_API_COMPLETE\n");
val _ = print ("SOLVER_PATH " ^ SatSolvers.getSolverExe SatSolvers.minisatp ^ "\n");
val _ = OS.Process.exit OS.Process.success;

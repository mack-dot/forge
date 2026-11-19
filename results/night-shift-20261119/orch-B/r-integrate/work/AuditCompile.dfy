// r-integrate: checks that SinkCoreV3.AuditStart compiles (translate js) and runs on two concrete cores.
include "../src/SinkCoreV3.dfy"

module AuditCompile {
  import opened SinkCoreV3

  method {:print} Main()
  {
    var good := Core(F.Charge("ch_1", 100, 90, true), {"rq_1"}, [R.Intent("ch_1", "rq_1", 10, "duplicate_charge")]);
    var foreign := Core(F.Charge("ch_1", 100, 90, true), {"rq_1"}, [R.Intent("ch_2", "rq_1", 10, "duplicate_charge")]);
    var unsettled := Core(F.Charge("ch_1", 100, 90, true), {"rq_x"}, [R.Intent("ch_1", "rq_1", 10, "duplicate_charge")]);
    print AuditStart(good), " ", AuditStart(foreign), " ", AuditStart(unsettled), "\n";
  }
}

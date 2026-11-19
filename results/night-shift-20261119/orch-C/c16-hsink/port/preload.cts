// c16 port policy for the h1 dispatcher (NOT part of the target). An honest host sets cfg.newLedgerH0 = genesisOf(...)
// ONLY when the ledger file is missing or empty (its first run). PORT_LEDGER_POLICY=first (default) | always | never.
const { readFileSync, existsSync } = require("node:fs");
const ROOT = "/private/tmp/claude-501/-Users-mackianni-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/redteam-C/fix-608b5165";
const D = require(ROOT + "/ts/refund-finality/dispatcher.ts");
const S = require(ROOT + "/ts/refund-finality/sink.ts");
const { DatabaseSync } = require("node:sqlite");
const pol = process.env.PORT_LEDGER_POLICY ?? "first";
const orig = D.Dispatcher.prototype.flush;
D.Dispatcher.prototype.flush = function (this: any) {
  const empty = !existsSync(this.ledgerPath) || readFileSync(this.ledgerPath, "utf8").length === 0;
  const had = this.cfg.newLedgerH0;
  if (had === undefined && (pol === "always" || (pol === "first" && empty))) {
    try {
      const db = new DatabaseSync(this.dbPath, { readOnly: true });
      const m = db.prepare("SELECT initial_state FROM meta").get() as any; db.close();
      if (m) this.cfg = { ...this.cfg, newLedgerH0: S.genesisOf(m.initial_state, this.cfg.specLockSha256, this.cfg.checkerSha256, this.cfg.publicKeyPem) };
    } catch { /* leave unset */ }
  }
  try { return orig.call(this); } finally { if (had === undefined) { const { newLedgerH0, ...rest } = this.cfg; this.cfg = rest; } }
};

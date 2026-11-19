// COPY of orch-C/c25-provider/realprov.ts (h-provider3), unchanged below this line.
// c25-provider (red team C): a FAKE provider that behaves like real payment providers, as switches. TEST ONLY.
// It replaces FakeProvider.prototype.refund of B's tree (same class, same ProviderError, same state-file format), so
// B's adapter (emit_adapter.ts) and B's p_*.ts scenarios run unchanged against it. No network. Switches (env):
//   RP_REPLAY  = error (default: same key, other params -> param_mismatch error, B's PARAM-BINDING)
//              | first (same key -> the FIRST result again, whatever the params: no body comparison)
//   RP_RET     = none (default) | <ticks>: the key is forgotten <ticks> after first use (ticks = hours in B's tests)
//   RP_CEIL    = 1 (default) | 0 : per-charge refund total <= captured amount
//   RP_KEYMAX  = <n> (default 255) and RP_KEYPOLICY = reject (default) | truncate ; keys must be printable ASCII
//                (an HTTP header value); reject -> non-retryable "invalid_request"
//   RP_SHARED  = <path>: ONE account state shared by every FakeProvider instance (key scope = the account)
//   RP_EMPTYKEY= nokey : an empty key is treated as NO key (every call is a new request)
//   RP_INFLIGHT= 1 : after a timeout_after_money fault the key stays "in flight" for the next call -> "conflict" (409)
// Zero amount: refused (as B's fake). Unknown charge: refused.
import { existsSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { join } from "node:path";

export function install(root: string): any {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const FP = require(join(root, "tests/refund-finality/provider/fake_provider.ts"));
  const { FakeProvider, ProviderError } = FP;
  const env = process.env;
  const REPLAY = env.RP_REPLAY ?? "error", RET = env.RP_RET && env.RP_RET !== "none" ? Number(env.RP_RET) : null;
  const CEIL = (env.RP_CEIL ?? "1") === "1", KEYMAX = Number(env.RP_KEYMAX ?? "255"), KEYPOL = env.RP_KEYPOLICY ?? "reject";
  const SHARED = env.RP_SHARED, INFLIGHT = env.RP_INFLIGHT === "1";
  const err = (code: string, msg: string) => new ProviderError(code, msg);
  const loadP = (self: any): any => {
    const own = JSON.parse(readFileSync(self.statePath, "utf8"));
    if (!SHARED) return { s: own, save: (s: any) => self.save(s) };
    let sh: any;
    if (existsSync(SHARED)) sh = JSON.parse(readFileSync(SHARED, "utf8"));
    else sh = { now: 0, charges: {}, movements: [], keys: {}, faults: [], calls: 0, options: own.options, inflight: {} };
    Object.assign(sh.charges, own.charges);
    sh.faults.push(...own.faults); own.faults = []; sh.now = Math.max(sh.now, own.now);
    self.save(own);
    return { s: sh, save: (x: any) => { writeFileSync(SHARED + ".tmp", JSON.stringify(x)); renameSync(SHARED + ".tmp", SHARED); } };
  };
  const paramsOf = (c: any) => JSON.stringify([c.chargeId, c.amount, c.reason]);
  FakeProvider.prototype.refund = function (call: any) {
    const { s, save } = loadP(this);
    s.calls++; s.inflight ??= {};
    // key handling at the client/provider boundary
    let key: string = call.key;
    if (key === "" && env.RP_EMPTYKEY === "nokey") key = "<nokey>#" + s.calls;   // empty header = no idempotency
    if (!/^[\x20-\x7e]*$/.test(key)) { save(s); throw err("invalid_request", "idempotency key is not printable ASCII"); }
    if (key.length > KEYMAX) {
      if (KEYPOL === "reject") { save(s); throw err("invalid_request", "idempotency key longer than " + KEYMAX); }
      key = key.slice(0, KEYMAX);
    }
    if (RET !== null) for (const [k, r] of Object.entries<any>(s.keys)) if (s.now - r.at >= RET) delete s.keys[k];
    if (INFLIGHT && s.inflight[key]) { delete s.inflight[key]; save(s); throw err("conflict", "a request with this key is in progress"); }
    const fi = s.faults.findIndex((f: any) => f.key === call.key);
    const fault = fi >= 0 ? s.faults.splice(fi, 1)[0] : undefined;
    if (fault?.kind === "crash_before_money") { save(s); throw err("unavailable", "crashed before any money moved"); }
    if (fault?.kind === "refuse") { save(s); throw err("refused", "declined"); }
    const seen = s.keys[key];
    if (seen !== undefined) {
      save(s);
      if (REPLAY === "error" && seen.params !== paramsOf(call)) throw err("param_mismatch", "key " + key + " used with other parameters");
      return { ...seen.result, replayed: true };               // "first": the stored result, no body comparison
    }
    if (call.amount === "0") { save(s); throw err("zero_amount", "a zero amount is refused"); }
    const charge = s.charges[call.chargeId];
    if (charge === undefined) { save(s); throw err("unknown_charge", call.chargeId); }
    if (CEIL) {
      const moved = s.movements.filter((m: any) => m.chargeId === call.chargeId).reduce((t: bigint, m: any) => t + BigInt(m.amount), 0n);
      if (moved + BigInt(call.amount) > BigInt(charge)) { save(s); throw err("ceiling", "refunds would exceed the charge amount"); }
    }
    const refundId = "re_" + (s.movements.length + 1);
    const result = { refundId, chargeId: call.chargeId, amount: call.amount, replayed: false };
    s.movements.push({ refundId, key, chargeId: call.chargeId, amount: call.amount, at: s.now });
    s.keys[key] = { params: paramsOf(call), result, at: s.now };
    if (fault?.kind === "timeout_after_money" && INFLIGHT) s.inflight[key] = true;
    save(s);
    if (fault?.kind === "timeout_after_money") throw err("timeout", "no answer (the money moved)");
    return result;
  };
  if (SHARED) {   // test controls and checks read the shared account
    const sh = () => JSON.parse(readFileSync(SHARED, "utf8"));
    FakeProvider.prototype.movements = function () { return existsSync(SHARED) ? sh().movements : []; };
    FakeProvider.prototype.calls = function () { return existsSync(SHARED) ? sh().calls : 0; };
  }
  return FP;
}
export function sharedState(): any { return JSON.parse(readFileSync(process.env.RP_SHARED!, "utf8")); }

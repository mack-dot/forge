// h-provider3 regression for the worker report "key text" (red team summary item 5a; attacker: none). A request id that
// encoding.ts accepts (<= 256 UTF-16 units, no U+0000, no lone surrogate) but that is not a valid idempotency key at many
// providers (printable ASCII, at most 255). The fake provider checks key text (keyText {max 255, asciiOnly}).
// usage: p3_keytext.ts <tree> [long|nonascii]   long: 256 x "x"; nonascii: "remboursé-1"; then r_next 100.
// Old adapter: the provider refuses the key; the committed refund is never paid (FALSE REJECTION, T6): exit 1.
// New adapter: the key is 64 hex characters; both refunds paid once: exit 0. Usage and exit codes: p3_lib.ts.
import { emittedOf, journalOf, root, truth, verdict } from "./p3_lib";
import { guard, world } from "./p_lib";
guard(() => {
  const tree = root(), kase = process.argv[3] ?? "long";
  const ids: Record<string, string> = { long: "x".repeat(256), nonascii: "remboursé-1" };
  if (ids[kase] === undefined) { console.error("usage: <tree> [long|nonascii]"); process.exit(4); }
  const w = world(tree, "b", "none", { chargeId: "ch_kt", original: "1000", remaining: "1000", refundEnabled: true }, { providerOptions: { keyText: { max: 255, asciiOnly: true } } });
  const c1 = w.refund(ids[kase], "300"); const f1 = w.flush();
  const c2 = w.refund("r_next", "100"); const f2 = w.flush();
  if (c1.status !== "committed" || c2.status !== "committed") { console.error("SETUP FAILED " + JSON.stringify({ c1, c2 })); process.exit(3); }
  const em = [...emittedOf(w, f1), ...emittedOf(w, f2)], mv = w.provider.movements();
  const problems = truth(mv, em, { ch_kt: "1000" }, [{ w, lines: journalOf(w) }]);
  const paid = new Set(em.map(e => e.requestId));
  for (const id of [ids[kase], "r_next"]) if (!paid.has(id)) problems.push("T6 FALSE REJECTION: committed refund " + JSON.stringify(id.slice(0, 12)) + " (len " + id.length + ") not paid");
  w.stop();
  verdict("p3_keytext " + kase, problems, { f1, f2, journal: journalOf(w).map(j => j.outcome), movements: mv.map(m => m.key.slice(0, 12) + ":" + m.amount) });
});

// Light self-test of witness_file.ts (one short run). Test data only.
import { mkdtempSync, rmSync, writeFileSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { FileWitness, genesisHash, headOf, linkHash } from "./witness_file";
const root = mkdtempSync(join(process.env.HOME || "/tmp", "wit-"));
const w = new FileWitness(join(root, "witness"));
const res = (name: string, f: () => unknown) => { try { const v = f(); console.log("OK     " + name + (v === undefined ? "" : " " + JSON.stringify(v))); } catch (e) { console.log("REFUSE " + name + ": " + (e as Error).message); } };
const h0 = genesisHash('{"chargeId":"ch_1","original":"100","refundEnabled":true,"remaining":"100"}', "a".repeat(64), "b".repeat(64), "PEM");
const rows = [{ token: "T1", intent: "I1(10)" }, { token: "T2", intent: "I2(0)" }, { token: "T3", intent: "I3(0)" }];
res("latest before register", () => w.latestHead("ch_1"));
res("register", () => w.register("ch_1", h0));
res("register twice", () => w.register("ch_1", h0));
let cur = headOf(h0, []);
for (let i = 1; i <= 3; i++) { const nx = headOf(h0, rows.slice(0, i)); res("publish n=" + i, () => w.publishHead("ch_1", cur, nx)); cur = nx; }
res("latest", () => w.latestHead("ch_1").n);
res("stale CAS from n=1 (rolled-back sink) with a fork n=4", () => w.publishHead("ch_1", headOf(h0, rows.slice(0, 1)), { n: 4, h: linkHash(headOf(h0, rows.slice(0, 1)).h, "T9", "I9") }));
res("republish older head", () => w.publishHead("ch_1", cur, headOf(h0, rows.slice(0, 2))));
res("start check: rolled-back store [T1]", () => { const s = headOf(h0, rows.slice(0, 1)), L = w.latestHead("ch_1"); if (s.n < L.n) throw new Error("store is behind the witness"); });
res("start check: zero row T2 deleted [T1,T3]", () => { const s = headOf(h0, [rows[0], rows[2]]), L = w.latestHead("ch_1"); if (s.n !== L.n || s.h !== L.h) throw new Error("store head differs"); });
res("start check: zero rows swapped", () => { const s = headOf(h0, [rows[0], rows[2], rows[1]]), L = w.latestHead("ch_1"); if (s.h !== L.h) throw new Error("store head differs"); });
res("start check: forged initial charge", () => { const f0 = genesisHash('{"chargeId":"ch_1","original":"100","refundEnabled":true,"remaining":"1000"}', "a".repeat(64), "b".repeat(64), "PEM"); const s = headOf(f0, rows); if (s.h !== w.latestHead("ch_1").h) throw new Error("store head differs"); });
res("start check: honest store", () => { const s = headOf(h0, rows), L = w.latestHead("ch_1"); if (s.h !== L.h) throw new Error("differs"); return "equal"; });
const f = join(root, "witness", "ch_1.heads"); const lines = readFileSync(f, "utf8").split("\n").filter(Boolean);
writeFileSync(f, lines.slice(0, 2).join("\n") + "\n");  // the witness file truncated: ANCHOR-MONOTONE violated
res("after truncation (ANCHOR-MONOTONE violated) latest", () => w.latestHead("ch_1").n);
rmSync(root, { recursive: true, force: true });

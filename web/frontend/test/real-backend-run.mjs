// One pass of the built page (`out/`) against the backend that listens on the
// API base (default http://127.0.0.1:8787). Start the backend first (see
// web/README.md). This script starts NO test double. It serves the page on
// 127.0.0.1:3000 (an origin that the backend allows by default), walks the
// story and some preset turns, takes screenshots, and prints what the page
// showed next to what the backend sent. Exit 0: the page showed the received values.
//
//   SHOTS_DIR=/some/folder node test/real-backend-run.mjs
import { mkdir } from "node:fs/promises";
import path from "node:path";
import { chromium } from "playwright-core";
import { serveOut } from "./serve-out.mjs";

const SHOTS = process.env.SHOTS_DIR ?? path.join(import.meta.dirname, ".shots-real");
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let failed = 0;
const check = (name, ok, detail = "") => {
  if (!ok) failed += 1;
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? `  [${detail}]` : ""}`);
};

await mkdir(SHOTS, { recursive: true });
const server = await serveOut(3000);
const browser = await chromium.launch({ channel: "chrome", headless: true });
try {
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  const tid = (id) => page.locator(`[data-testid="${id}"]`);
  const text = async (id) => (await tid(id).last().textContent())?.trim() ?? null;
  const got = { health: null, vent: null, telemetry: null, events: [] };
  const foreign = [];
  page.on("request", (r) => {
    const u = new URL(r.url());
    if (u.protocol !== "data:" && u.hostname !== "127.0.0.1") foreign.push(r.url());
  });
  page.on("response", async (r) => {
    try {
      if (r.url().endsWith("/api/health")) got.health = await r.json();
      if (r.url().endsWith("/api/story/vent")) got.vent = await r.json();
      if (r.url().endsWith("/api/telemetry") && r.ok()) got.telemetry = await r.json();
      if (r.url().endsWith("/api/chat") && r.ok()) got.events.push(await r.text());
    } catch {}
  });

  await page.goto("http://127.0.0.1:3000/");
  await tid("intercept-overlay").waitFor({ timeout: 45000 });
  await sleep(3200);
  await page.screenshot({ path: path.join(SHOTS, "real-01-interception.png") });
  console.log("health      :", JSON.stringify({ ok: got.health?.ok, engine: got.health?.engine, model: got.health?.model, what_ran: got.health?.what_ran }));
  console.log("story vent  :", JSON.stringify({ ...got.vent, scoreboard: undefined }));
  check("overlay engine_request = response", (await text("engine-request")) === got.vent?.engine_request);
  check("overlay engine_answer = response", (await text("engine-answer")) === got.vent?.engine_answer, got.vent?.engine_answer);
  check("overlay latency = response", (await text("latency"))?.startsWith(String(got.vent?.latency_ms)), String(got.vent?.latency_ms));
  await tid("take-console").click();
  await tid("presets").locator("button").first().waitFor({ timeout: 8000 });
  await sleep(1500);

  const ids = await tid("presets").locator("button").evaluateAll((bs) => bs.map((b) => b.getAttribute("data-testid")));
  console.log("presets     :", ids.join(" "));
  for (const id of ids.slice(0, 4)) {
    const n = await tid("turn").count();
    await tid(id).click();
    await page.waitForFunction((i) => { const t = document.querySelectorAll('[data-testid="turn"]')[i]; return t && t.getAttribute("data-state") !== "streaming"; }, n, { timeout: 30000 });
    const t = tid("turn").nth(n);
    const shown = {
      preset: id,
      assumed: (await t.locator('[data-testid="assumed"]').count()) > 0,
      chip: (await t.locator('[data-testid="verdict-chip"]').count()) ? await t.locator('[data-testid="verdict-chip"]').textContent() : null,
      answer: (await t.locator('[data-testid="engine-answer"]').count()) ? await t.locator('[data-testid="engine-answer"]').textContent() : null,
      latency: (await t.locator('[data-testid="latency"]').count()) ? await t.locator('[data-testid="latency"]').textContent() : null,
      not_sent: (await t.locator('[data-testid="local-refusal"]').count()) > 0,
      no_command: (await t.locator('[data-testid="tool-null"]').count()) > 0,
      error: (await t.locator('[data-testid="turn-error"]').count()) ? await t.locator('[data-testid="turn-error"]').getAttribute("data-code") : null,
    };
    console.log("turn shown  :", JSON.stringify(shown));
    const raw = got.events[got.events.length - 1] ?? "";
    const m = /event: verdict\ndata: (.*)\n/.exec(raw);
    if (m) {
      const v = JSON.parse(m[1]);
      check(`turn ${id}: shown engine_answer = stream verdict`, shown.answer === v.engine_answer, v.engine_answer);
    }
    await sleep(500);
    await page.screenshot({ path: path.join(SHOTS, `real-02-turn-${id.replace("preset-", "")}.png`) });
  }
  await sleep(2000);
  const tm = got.telemetry;
  console.log("telemetry   :", JSON.stringify(tm));
  check(
    "panel = last telemetry response",
    tm &&
      (await text("tm-refusals")) === String(tm.engine_refusals) &&
      (await text("tm-commands")) === String(tm.commands_sent) &&
      (await text("tm-vent-commits")) === String(tm.vent_commits) &&
      (await text("tm-store-effects")) === String(tm.store_effects) &&
      (await text("tm-rss-peak")) === String(tm.engine_peak_rss_kib) &&
      (await text("tm-crew")) === tm.crew_status &&
      (await text("tm-reconciled")) === String(tm.reconciled) &&
      (await text("tm-expected-effects")) === String(tm.expected_effects) &&
      (await text("tm-vent-quota")) === String(tm.bay3_vent_quota_fact) &&
      (await text("tm-unexpected")) === String(tm.unexpected_answers),
    JSON.stringify({ refusals: await text("tm-refusals"), crew: await text("tm-crew"), peak: await text("tm-rss-peak") }),
  );
  check(
    "no breach and no unknown state, as the scoreboard and health say",
    (await tid("stage").getAttribute("data-breach")) === "false" &&
      (await tid("stage").getAttribute("data-unknown")) === "false" &&
      tm?.vent_commits === 0 &&
      tm?.store_effects === tm?.store_effects_baseline &&
      tm?.reconciled === true &&
      tm?.canary_ok === true &&
      got.health?.ok === true,
  );
  await page.screenshot({ path: path.join(SHOTS, "real-02b-telemetry.png") });
  const sha = got.health?.what_ran?.engine_sha256;
  await tid("footer-sha").focus();
  check("footer: short SHA-256 of the engine, full value on focus", (await text("footer-sha"))?.startsWith(`sha256 ${String(sha).slice(0, 12)}…`) && (await tid("footer-sha-full").textContent()) === sha, String(sha));
  await tid("limits-open").click();
  await sleep(400);
  await page.screenshot({ path: path.join(SHOTS, "real-03-limits-drawer.png") });
  console.log("limits shown:", await tid("limits-list").locator("li").count(), "of", got.health?.limits?.length);
  check("drawer: full SHA-256 and the cosign label as received", (await text("drawer-sha")) === sha && (await text("drawer-cosign-label")) === got.health?.what_ran?.cosign_label, got.health?.what_ran?.cosign_label);
  check("the page does not mention Node", !/\bnode\b/i.test(await page.evaluate(() => document.body.innerText)));
  check("no request left 127.0.0.1", foreign.length === 0, foreign.join(" "));
  await ctx.close();
} catch (e) {
  check(`script error: ${e?.message?.split("\n")[0] ?? e}`, false);
} finally {
  await Promise.race([browser.close(), sleep(8000)]);
  server.closeAllConnections?.();
  server.close();
}
console.log(failed === 0 ? "\nall checks passed" : `\n${failed} check(s) failed`);
process.exit(failed === 0 ? 0 : 1);

#!/usr/bin/env node
// Synthetic playtest logs for .tools/playtest_report.js, with planted answers, then checks the markdown it writes.
//   node .tools/playtest_report_test.js [--keep <folder>]
// Three testers: "ana" (a session that closed unexpectedly, then a finished run), "boris" (stopped at week 12
// with two script errors) and one loose file. Event A always gets its first choice; event B never gets its last.
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

const ROOT = path.resolve(__dirname, "..");
const keep = process.argv.indexOf("--keep");
const dir = keep > 0 ? path.resolve(process.argv[keep + 1]) : fs.mkdtempSync(path.join(os.tmpdir(), "playtest_synth_"));
const out = path.join(dir, "results_test.md");

const base = JSON.parse(fs.readFileSync(path.join(ROOT, "data", "events.json"), "utf8"));
const pool = JSON.parse(fs.readFileSync(path.join(ROOT, "data", "events_pool.json"), "utf8"));
const list = [...(Array.isArray(base) ? base : base.events), ...pool.events].filter((e) => (e.choices || []).length >= 3);
const A = list[0];
const B = list[1];
const C = list[2];

function session(file, opts) {
  const rows = [];
  let t = 0;
  let active = 0;
  const push = (row) => rows.push(Object.assign({ t: Math.round(t * 10) / 10 }, row));
  push({ event: "session_start", version: "0.1.0-playtest1", build: "synth", language: opts.lang, resolution: "1920x1080", fullscreen: false, os: "Windows", godot_version: "4.7.2-stable" });
  for (let w = opts.from; w <= opts.to; w++) {
    push({ event: "week_start", week: w, real_seconds_since_start: Math.round(t), active_seconds: active, hope: 60 - w, discontent: 10 + w, stocks: { food: 40, air: 30 } });
    push({ event: "dawn_events", week: w, ids: [A.id, B.id, C.id] });
    const spend = opts.seconds(w);
    t += spend;
    active += spend;
    push({ event: "decision", kind: "event_choice", id: A.id, choice: A.choices[0].id, week: w });
    push({ event: "decision", kind: "event_choice", id: B.id, choice: B.choices[w % 2].id, week: w });
    push({ event: "decision", kind: "build", id: "hydroponics", choice: "build", week: w });
    if (w === opts.idleWeek) {
      t += 300;
      push({ event: "idle", seconds: 300 });
    }
    if (w === 4) push({ event: "audience", leader: "synod", answer: opts.answer, week: w });
    if (w === 6) push({ event: "fragment", id: "depot_order", how: opts.how, week: w });
    if (opts.errorWeeks && opts.errorWeeks.includes(w)) push({ event: "error", text: "Invalid access to key 'law' (game.gd:195 setup)", week: w });
  }
  if (opts.ending) push({ event: "ending", id: opts.ending, week: opts.to, proofs: 2 });
  if (!opts.crash) {
    push({ event: "session_end", week: opts.to, ending: opts.ending || "", real_minutes: Math.round(t / 6) / 10, active_minutes: Math.round(active / 6) / 10 });
  }
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
}

session(path.join(dir, "ana", "session_20261012_090000.jsonl"), { lang: "ru", from: 1, to: 5, seconds: () => 60, crash: true, answer: "accepted", how: "honest" });
session(path.join(dir, "ana", "session_20261012_100000.jsonl"), { lang: "ru", from: 5, to: 40, seconds: (w) => (w === 20 ? 900 : 100), ending: "winter", answer: "accepted", how: "honest", idleWeek: 10 });
session(path.join(dir, "boris", "session_20261012_110000.jsonl"), { lang: "en", from: 1, to: 12, seconds: (w) => (w === 3 ? 700 : 120), errorWeeks: [2, 7], answer: "refused", how: "dirty" });
session(path.join(dir, "session_20261012_120000.jsonl"), { lang: "en", from: 1, to: 8, seconds: () => 90, answer: "refused", how: "dirty" });
fs.appendFileSync(path.join(dir, "session_20261012_120000.jsonl"), "{not json\n");

execFileSync(process.execPath, [path.join(__dirname, "playtest_report.js"), dir, "--out", out, "--date", "20261012"], { stdio: "inherit" });
const md = fs.readFileSync(out, "utf8");
const want = [
  "# Playtest results 2026-10-12",
  "4 session files of 3 testers",
  "1 lines did not parse",
  "| ana | 2 | 1 |",
  "| 40 | winter |",
  "| boris | 1 | 0 |",
  "| 12 | not finished |",
  "| session_20261012_120000 | 1 | 0 |",
  "- week 20, ana: 900 s",
  "- week 3, boris: 700 s",
  `always: ${A.choices[0].id}`,
  `never: ${B.choices[2].id}`,
  `Always taken: ${A.id}.${A.choices[0].id}`,
  `${B.id}.${B.choices[2].id}`,
  "| build hydroponics (build) |",
  "| synod | accepted 1, refused 2 |",
  "| depot_order | 3 | honest 1, dirty 2 |",
  "| error: Invalid access to key 'law' (game.gd:195 setup) | 2 | 1 | 2, 7 |",
];
const missing = want.filter((w) => !md.includes(w));
const week1 = md.split("\n").find((l) => l.startsWith("| 1 | 3 |"));
if (!week1 || !week1.includes("| 90 |")) missing.push("week 1 row with 3 testers, mean 90 s: " + week1);
if (missing.length) {
  console.log(md);
  console.log("MISSING:\n  " + missing.join("\n  "));
  console.log("PLAYTEST REPORT TEST FAILED");
  process.exit(1);
}
console.log(`Synthetic logs in ${dir}`);
console.log("PLAYTEST REPORT TEST OK");

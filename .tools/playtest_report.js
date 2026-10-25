#!/usr/bin/env node
// Reads a folder of playtest logs (session_*.jsonl, as written by sim/playtest_log.gd) and writes
// docs/playtest/results_YYYYMMDD.md. Files in a subfolder belong to one tester (name the folder after them);
// files lying directly in the folder count as one tester each.
//   node .tools/playtest_report.js <logs folder> [--out <file.md>] [--date YYYYMMDD]
// Event and choice names come from data/events*.json, so choices nobody took show up too.
"use strict";
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");

function args() {
  const a = process.argv.slice(2);
  const out = { folder: "", out: "", date: "" };
  for (let i = 0; i < a.length; i++) {
    if (a[i] === "--out") out.out = a[++i];
    else if (a[i] === "--date") out.date = a[++i];
    else out.folder = a[i];
  }
  if (!out.folder) {
    console.error("usage: node .tools/playtest_report.js <logs folder> [--out file.md] [--date YYYYMMDD]");
    process.exit(2);
  }
  if (!out.date) {
    const d = new Date();
    out.date = `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, "0")}${String(d.getDate()).padStart(2, "0")}`;
  }
  if (!out.out) out.out = path.join(ROOT, "docs", "playtest", `results_${out.date}.md`);
  return out;
}

function sessionFiles(dir) {
  const found = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      for (const f of sessionFiles(full)) found.push(f);
    } else if (/^session_.*\.jsonl$/.test(entry.name)) {
      found.push(full);
    }
  }
  return found.sort();
}

function readRows(file) {
  const rows = [];
  let bad = 0;
  for (const line of fs.readFileSync(file, "utf8").split(/\r?\n/)) {
    if (!line.trim()) continue;
    try {
      const row = JSON.parse(line);
      if (row && typeof row === "object" && !Array.isArray(row)) rows.push(row);
      else bad++;
    } catch (e) {
      bad++;
    }
  }
  return { rows, bad };
}

function loadEvents() {
  const events = {};
  const add = (list, source) => {
    for (const ev of list || []) {
      if (!ev || !ev.id) continue;
      events[ev.id] = { title: ev.title || ev.id, source, choices: (ev.choices || []).map((c) => ({ id: c.id, label: c.label || c.id })) };
    }
  };
  const read = (name) => {
    try {
      return JSON.parse(fs.readFileSync(path.join(ROOT, "data", name), "utf8"));
    } catch (e) {
      return null;
    }
  };
  const base = read("events.json");
  add(Array.isArray(base) ? base : base && base.events, "events");
  for (const name of ["events_pool.json", "events_leaders.json", "events_story.json"]) {
    const data = read(name);
    if (data) add(data.events, name.replace(".json", ""));
  }
  return events;
}

// Active seconds per week inside one session: from a week_start to the next week_start or session_end.
function weekSeconds(rows) {
  const out = {};
  let open = -1;
  let at = 0;
  for (const row of rows) {
    if (row.event !== "week_start" && row.event !== "session_end") continue;
    const now = row.event === "session_end" ? Number(row.active_minutes || 0) * 60 : Number(row.active_seconds ?? -1);
    if (open >= 0 && now >= at) out[open] = (out[open] || 0) + Math.round(now - at);
    open = row.event === "week_start" ? Number(row.week || 0) : -1;
    at = now;
  }
  return out;
}

// Active minutes of a session: session_end when it closed cleanly, otherwise the last row's time minus idle gaps.
function activeMinutes(rows) {
  const end = rows.find((r) => r.event === "session_end");
  if (end) return Number(end.active_minutes || 0);
  let last = 0;
  let idle = 0;
  for (const r of rows) {
    last = Math.max(last, Number(r.t || 0));
    if (r.event === "idle") idle += Number(r.seconds || 0);
  }
  return Math.max(0, (last - idle) / 60);
}

function mean(list) {
  return list.length ? list.reduce((a, b) => a + b, 0) / list.length : 0;
}

function fmt(n, digits = 1) {
  return Number(n).toFixed(digits);
}

function cell(text) {
  return String(text).replace(/\|/g, "\\|").replace(/\r?\n/g, " ");
}

function main() {
  const opt = args();
  const folder = path.resolve(opt.folder);
  const files = sessionFiles(folder);
  const events = loadEvents();
  const testers = new Map();
  let badLines = 0;
  for (const file of files) {
    const rel = path.relative(folder, file);
    const parts = rel.split(path.sep);
    const who = parts.length > 1 ? parts[0] : path.basename(file, ".jsonl");
    const { rows, bad } = readRows(file);
    badLines += bad;
    if (!testers.has(who)) testers.set(who, []);
    testers.get(who).push({ file: rel, rows });
  }

  const perTester = [];
  const weekTime = {};
  const weekDecisions = {};
  const choiceCount = {};
  const eventSeen = {};
  const otherDecisions = {};
  const audience = {};
  const fragments = {};
  const errors = {};
  const slow = [];

  for (const [who, sessions] of testers) {
    let minutes = 0;
    let reached = 0;
    let ending = "";
    let crashed = 0;
    let errorCount = 0;
    let decisions = 0;
    const langs = new Set();
    const versions = new Set();
    const seconds = {};
    const perWeekDecisions = {};
    const seenHere = new Set();
    for (const s of sessions) {
      minutes += activeMinutes(s.rows);
      if (!s.rows.some((r) => r.event === "session_end")) crashed++;
      for (const [w, sec] of Object.entries(weekSeconds(s.rows))) seconds[w] = (seconds[w] || 0) + sec;
      for (const r of s.rows) {
        switch (r.event) {
          case "session_start":
            if (r.language) langs.add(r.language);
            if (r.version) versions.add(`${r.version} (${r.build || "?"})`);
            break;
          case "settings":
            if (r.language) langs.add(r.language);
            break;
          case "week_start":
            reached = Math.max(reached, Number(r.week || 0));
            break;
          case "dawn_events":
            for (const id of r.ids || []) seenHere.add(id);
            break;
          case "ending":
            ending = r.id || ending;
            break;
          case "decision": {
            decisions++;
            const w = Number(r.week || 0);
            perWeekDecisions[w] = (perWeekDecisions[w] || 0) + 1;
            if (r.kind === "event_choice") {
              seenHere.add(r.id);
              choiceCount[r.id] = choiceCount[r.id] || {};
              choiceCount[r.id][r.choice] = (choiceCount[r.id][r.choice] || 0) + 1;
            } else {
              const key = `${r.kind} ${r.id}${r.choice ? " (" + r.choice + ")" : ""}`;
              otherDecisions[key] = otherDecisions[key] || { count: 0, testers: new Set() };
              otherDecisions[key].count++;
              otherDecisions[key].testers.add(who);
            }
            break;
          }
          case "audience": {
            const leader = r.leader || "?";
            audience[leader] = audience[leader] || {};
            audience[leader][r.answer] = (audience[leader][r.answer] || 0) + 1;
            break;
          }
          case "fragment": {
            const id = r.id || "?";
            fragments[id] = fragments[id] || { testers: new Set(), how: {} };
            fragments[id].testers.add(who);
            fragments[id].how[r.how] = (fragments[id].how[r.how] || 0) + 1;
            break;
          }
          case "error":
          case "warning": {
            if (r.event === "error") errorCount++;
            const key = `${r.event}: ${r.text}`;
            errors[key] = errors[key] || { count: 0, testers: new Set(), weeks: new Set() };
            errors[key].count++;
            errors[key].testers.add(who);
            errors[key].weeks.add(r.week);
            break;
          }
        }
      }
    }
    for (const id of seenHere) {
      eventSeen[id] = eventSeen[id] || new Set();
      eventSeen[id].add(who);
    }
    for (const [w, sec] of Object.entries(seconds)) {
      weekTime[w] = weekTime[w] || [];
      weekTime[w].push(sec);
      slow.push({ who, week: Number(w), sec });
    }
    for (let w = 1; w <= reached; w++) {
      weekDecisions[w] = weekDecisions[w] || [];
      weekDecisions[w].push(perWeekDecisions[w] || 0);
    }
    perTester.push({
      who, sessions: sessions.length, crashed, minutes, reached, ending: ending || "not finished", decisions,
      langs: [...langs].join(", "), versions: [...versions].join(", "), errors: errorCount,
    });
  }

  const L = [];
  L.push(`# Playtest results ${opt.date.slice(0, 4)}-${opt.date.slice(4, 6)}-${opt.date.slice(6, 8)}`);
  L.push("");
  L.push(`Made by \`.tools/playtest_report.js\` from ${files.length} session files of ${testers.size} testers in \`${path.relative(ROOT, folder) || folder}\`.` +
    (badLines ? ` ${badLines} lines did not parse and were skipped.` : " Every line parsed."));
  L.push("");
  L.push("## Testers");
  L.push("");
  L.push("| Tester | Sessions | Closed unexpectedly | Active minutes | Weeks reached | Ending | Decisions | Language | Version | Errors |");
  L.push("| --- | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | ---: |");
  for (const t of perTester) {
    L.push(`| ${cell(t.who)} | ${t.sessions} | ${t.crashed} | ${fmt(t.minutes)} | ${t.reached} | ${cell(t.ending)} | ${t.decisions} | ${cell(t.langs)} | ${cell(t.versions)} | ${t.errors} |`);
  }
  if (perTester.length) {
    L.push("");
    L.push(`Mean active minutes ${fmt(mean(perTester.map((t) => t.minutes)))}, mean weeks reached ${fmt(mean(perTester.map((t) => t.reached)))}, ` +
      `finished ${perTester.filter((t) => t.ending !== "not finished").length} of ${perTester.length}.`);
  }
  L.push("");
  L.push("## Time per week");
  L.push("");
  L.push("Active seconds from one week start to the next, idle gaps over two minutes left out. Mean over the testers who played that week.");
  L.push("");
  L.push("| Week | Testers | Mean s | Max s | Mean decisions |");
  L.push("| ---: | ---: | ---: | ---: | ---: |");
  const weeks = [...new Set([...Object.keys(weekTime), ...Object.keys(weekDecisions)].map(Number))].sort((a, b) => a - b);
  for (const w of weeks) {
    const t = weekTime[w] || [];
    const d = weekDecisions[w] || [];
    L.push(`| ${w} | ${Math.max(t.length, d.length)} | ${t.length ? fmt(mean(t), 0) : "-"} | ${t.length ? Math.max(...t) : "-"} | ${d.length ? fmt(mean(d)) : "-"} |`);
  }
  L.push("");
  L.push("Five slowest weeks across testers:");
  L.push("");
  slow.sort((a, b) => b.sec - a.sec || a.week - b.week);
  for (const s of slow.slice(0, 5)) L.push(`- week ${s.week}, ${cell(s.who)}: ${s.sec} s`);
  if (!slow.length) L.push("- none");
  L.push("");
  L.push("## Event choices");
  L.push("");
  L.push("Every event a tester saw at dawn or answered. Counts are answers over all testers. Never: a choice nobody took although the event came up at least three times. Always: one choice took every answer, at least three answers.");
  L.push("");
  L.push("| Event | Seen by | Answers | Choices (count) | Note |");
  L.push("| --- | ---: | ---: | --- | --- |");
  const never = [];
  const always = [];
  const ids = Object.keys(eventSeen).sort();
  for (const id of ids) {
    const counts = choiceCount[id] || {};
    const known = events[id] ? events[id].choices.map((c) => c.id) : [];
    const all = [...new Set([...known, ...Object.keys(counts)])];
    const total = Object.values(counts).reduce((a, b) => a + b, 0);
    const notes = [];
    const nobody = all.filter((c) => !counts[c]);
    if (total >= 3 && nobody.length) {
      notes.push("never: " + nobody.join(", "));
      for (const c of nobody) never.push(`${id}.${c}`);
    }
    const taken = Object.keys(counts).filter((c) => counts[c] > 0);
    if (total >= 3 && taken.length === 1) {
      notes.push("always: " + taken[0]);
      always.push(`${id}.${taken[0]}`);
    }
    if (!events[id]) notes.push("not in data");
    L.push(`| ${cell(id)} | ${eventSeen[id].size} | ${total} | ${all.map((c) => `${c} ${counts[c] || 0}`).join(", ")} | ${notes.join("; ")} |`);
  }
  L.push("");
  L.push(`Never taken: ${never.length ? never.join(", ") : "none"}.`);
  L.push("");
  L.push(`Always taken: ${always.length ? always.join(", ") : "none"}.`);
  L.push("");
  L.push("## Other decisions");
  L.push("");
  L.push("| Decision | Count | Testers |");
  L.push("| --- | ---: | ---: |");
  for (const [key, v] of Object.entries(otherDecisions).sort((a, b) => b[1].count - a[1].count || a[0].localeCompare(b[0]))) {
    L.push(`| ${cell(key)} | ${v.count} | ${v.testers.size} |`);
  }
  L.push("");
  L.push("## Audience answers");
  L.push("");
  L.push("| Leader | Answers |");
  L.push("| --- | --- |");
  for (const leader of Object.keys(audience).sort()) {
    L.push(`| ${cell(leader)} | ${Object.entries(audience[leader]).map(([a, n]) => `${a} ${n}`).join(", ")} |`);
  }
  if (!Object.keys(audience).length) L.push("| none | |");
  L.push("");
  L.push("## Fragments");
  L.push("");
  L.push("| Fragment | Testers | How |");
  L.push("| --- | ---: | --- |");
  for (const id of Object.keys(fragments).sort()) {
    L.push(`| ${cell(id)} | ${fragments[id].testers.size} | ${Object.entries(fragments[id].how).map(([h, n]) => `${h} ${n}`).join(", ")} |`);
  }
  if (!Object.keys(fragments).length) L.push("| none | | |");
  L.push("");
  L.push("## Errors");
  L.push("");
  const errs = Object.entries(errors).sort((a, b) => b[1].count - a[1].count);
  if (!errs.length) L.push("None logged.");
  else {
    L.push("| Message | Count | Testers | Weeks |");
    L.push("| --- | ---: | ---: | --- |");
    for (const [text, v] of errs) {
      L.push(`| ${cell(text.slice(0, 200))} | ${v.count} | ${v.testers.size} | ${[...v.weeks].sort((a, b) => a - b).join(", ")} |`);
    }
  }
  L.push("");
  fs.mkdirSync(path.dirname(opt.out), { recursive: true });
  fs.writeFileSync(opt.out, L.join("\n"), "utf8");
  console.log(`${files.length} files, ${testers.size} testers -> ${path.relative(ROOT, opt.out) || opt.out}`);
}

main();

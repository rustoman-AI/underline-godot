// Static localization audit: every player-visible string pair (EN source, RU) from code and data.
//   node .tools/l10n_audit.js            writes build/l10n/findings.json and prints counts
// Sources: Copy.t/gloss/person literals in sim/ and ui/, data fields the game shows through Copy.t,
// {en, ru} pairs, events' ru_own. Read only; it changes nothing.
const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");
const read = (p) => fs.readFileSync(path.join(root, p), "utf8");
const json = (p) => JSON.parse(read(p));

const map = Object.assign({}, json("data/ru.json"));
for (const f of ["events_pool.json", "events_leaders.json", "events_story.json"]) {
	const extra = json("data/" + f).ru || {};
	for (const en in extra) if (!(en in map)) map[en] = extra[en];
}

const pairs = []; // {en, ru, where, via}
const add = (en, ru, where, via) => pairs.push({ en: String(en ?? ""), ru: ru == null ? null : String(ru), where, via });

// Code literals through Copy.
const codeFiles = [];
for (const dir of ["sim", "ui"]) for (const f of fs.readdirSync(path.join(root, dir))) if (f.endsWith(".gd")) codeFiles.push(dir + "/" + f);
const lit = /Copy\.(t|gloss|person)\(\s*"((?:[^"\\]|\\.)*)"\s*\)/g;
const usedInCode = new Set();
for (const f of codeFiles) {
	const lines = read(f).split(/\r?\n/);
	lines.forEach((line, i) => {
		for (const m of line.matchAll(lit)) {
			const en = JSON.parse('"' + m[2] + '"');
			usedInCode.add(en);
			add(en, map[en] ?? null, `${f}:${i + 1}`, "code");
		}
	});
}

// Data shown through Copy.t (English source, Russian from the map).
const VISIBLE = new Set(["title", "text", "label", "name", "full", "desc", "short", "leader", "leader_title", "banner",
	"intro", "outcome", "before_silence", "keepsake", "find", "pay", "suffer", "lock_reason", "hint"]);
function walkMapped(value, file, trail, owner) {
	if (Array.isArray(value)) return value.forEach((v, i) => walkMapped(v, file, trail + "[" + i + "]", owner));
	if (!value || typeof value !== "object") return;
	if ("en" in value && "ru" in value && typeof value.en === "string") {
		add(value.en, value.ru, `${file} ${trail}`, "pair");
		return;
	}
	const own = value.ru_own && typeof value.ru_own === "object" ? value.ru_own : {};
	for (const k in value) {
		if (k === "ru" && trail === "" || k === "_note" || k === "ru_own") continue;
		const v = value[k];
		if (typeof v === "string" && VISIBLE.has(k) && /[A-Za-z]/.test(v)) {
			add(v, own[k] ?? map[v] ?? null, `${file} ${trail}.${k}`, own[k] ? "ru_own" : "map");
		} else if (typeof v === "object") {
			walkMapped(v, file, trail + "." + k, owner);
		}
	}
}
const dataFiles = fs.readdirSync(path.join(root, "data")).filter((f) => f.endsWith(".json") &&
	!["ru.json", "build_info.json", "map_geo.json", "map_pins.json", "cast_portraits.json", "balance.json", "tunnels.json",
		"start_grid.json", "station_communities.json", "station_communities_en.json", "names.json"].includes(f));
for (const f of dataFiles) walkMapped(json("data/" + f), "data/" + f, "", f);
// Communities: Russian file is the lead's source, English the companion.
const commRu = json("data/station_communities.json");
const commEn = json("data/station_communities_en.json");
for (const sid in commRu.stations || {}) {
	const row = commRu.stations[sid];
	const en = (commEn.stations || {})[sid] || {};
	for (const k of ["community", "who", "conflict"]) if (row[k] != null || en[k] != null) add(en[k] ?? "", row[k] ?? "", `data/station_communities ${sid}.${k}`, "communities");
}

// Checks.
const findings = { only_en: [], only_ru: [], latin_in_ru: [], cyrillic_in_en: [], raw_id: [], dash: [], plural_ru: [], plural_en: [], names: [] };
const RAW = /\b(?:[a-z]+_[a-z0-9_]+|st\d_\w*)\b/;
const RU_NOUN = /(%d|\b\d+)\s+(недел\S*|человек\S*|материал\S*|жетон\S*|истори\S*|рабоч\S*|бригад\S*|дн[еяи]\S*|раз\b|свидетельств\S*|доказательств\S*|ход\S*|голос\S*|житель\S*|комнат\S*|станци\S*)/i;
const EN_NOUN = /%d\s+(weeks|people|materials|tokens|stories|workers|crews|days|residents|rooms|stations|proofs|testimonies)\b/i;
const NAMES = [
	["Depot", /Депо/],
	["Lamplighters", /Фонарщик/],
	["Regard", /Отношени/],
	["Opinion", /Мнени/],
];
const ALLOWED_LATIN = /^(?:%[sd+]|[A-Z]{1,3}|x|ok|OK|VO|UI|FPS|Esc|Enter|Ctrl|Alt|Shift|Tab|Space|F\d+|Windows|itch|io|Underline|Discord|Steam)$/;
const seen = new Set();
for (const p of pairs) {
	const key = p.en + "\u0000" + (p.ru ?? "") + "\u0000" + p.via;
	if (seen.has(key)) continue;
	seen.add(key);
	const en = p.en, ru = p.ru;
	const row = { where: p.where, en, ru };
	if (en.trim() !== "" && (ru == null || ru.trim() === "")) {
		if (/[A-Za-z]{2}/.test(en) && !/^[%\d\s\W]+$/.test(en)) findings.only_en.push(row);
	}
	if (ru != null && ru.trim() !== "" && en.trim() === "") findings.only_ru.push(row);
	if (ru) {
		const words = (ru.replace(/%[-+0-9.]*[sdf]/g, " ").match(/[A-Za-z][A-Za-z']+/g) || []).filter((w) => !ALLOWED_LATIN.test(w));
		if (words.length) findings.latin_in_ru.push({ ...row, words: [...new Set(words)] });
	}
	if (/[А-Яа-яЁё]/.test(en)) findings.cyrillic_in_en.push(row);
	for (const [lang, s] of [["en", en], ["ru", ru || ""]]) {
		const m = s.match(RAW);
		if (m && !/%s/.test(m[0])) findings.raw_id.push({ ...row, lang, token: m[0] });
		if (/[—–]/.test(s)) findings.dash.push({ ...row, lang });
	}
	if (ru) {
		const m = ru.match(RU_NOUN);
		if (m) findings.plural_ru.push({ ...row, match: m[0] });
	}
	{
		const m = en.match(EN_NOUN);
		if (m) findings.plural_en.push({ ...row, match: m[0] });
	}
	if (ru) for (const [term, want] of NAMES) {
		if (new RegExp("\\b" + term + "\\b").test(en) && !want.test(ru)) findings.names.push({ ...row, term });
	}
}

// Literals shown in ui/*.gd without Copy (heuristic: sentence-like strings outside print/log/paths).
const bare = [];
for (const f of codeFiles.filter((f) => f.startsWith("ui/"))) {
	read(f).split(/\r?\n/).forEach((line, i) => {
		const t = line.trim();
		if (t.startsWith("#") || /print|push_error|push_warning|_log\(|res:\/\/|user:\/\/|Copy\.|\.has\(|==|match |begins_with|ends_with|get_node|\$|_dev|DEV|\bconst\b|"%s"|add_theme|theme_override|Sound\.|PlaytestLog\.event|Settings\.|"\w+":\s/.test(t)) return;
		for (const m of t.matchAll(/"((?:[^"\\]|\\.)*)"/g)) {
			const s = m[1];
			if (!/^[A-Z][a-z]+[ ,.][^"]*[a-z]/.test(s) || s.length < 6) continue;
			if (s in map) continue;
			bare.push({ where: `${f}:${i + 1}`, en: s });
		}
	});
}
findings.bare_ui_literal = bare;

// Every sentence-like literal in sim/ and ui/ (three words or more) that the Russian map does not know.
// Some are logs, dev text or keys for other lookups; the report sorts them by hand.
const loose = [];
for (const f of codeFiles) {
	if (/check_|bot_run|_checks\.gd|soak/.test(f)) continue;
	read(f).split(/\r?\n/).forEach((line, i) => {
		const t = line.trim();
		if (t.startsWith("#") || /\bprint\(|push_error|push_warning|errors\.append|_log\(|"res:\/\//.test(t)) return;
		for (const m of t.matchAll(/"((?:[^"\\]|\\.)*)"/g)) {
			let s;
			try { s = JSON.parse('"' + m[1] + '"'); } catch { continue; }
			if (!/^[A-Z%][^"]*\s\S+\s\S+/.test(s) || !/[a-z]{3}/.test(s)) continue;
			if (s in map || usedInCode.has(s) && map[s]) continue;
			loose.push({ where: `${f}:${i + 1}`, en: s });
		}
	});
}
findings.loose_literal = loose;

// Name usage across all RU strings for the terms the brief names.
const usage = {};
for (const ru of new Set(pairs.map((p) => p.ru).filter(Boolean))) {
	for (const [label, re] of [["Депо", /Депо/g], ["Депот", /Депот/g], ["Фонарщик", /Фонарщик/g], ["Ламп", /Лампов/g],
		["Отношение", /Отношени/g], ["Уважение", /Уважени/g], ["Мнение", /Мнени/g], ["Репутац", /Репутац/g]]) {
		const n = (ru.match(re) || []).length;
		if (n) usage[label] = (usage[label] || 0) + n;
	}
}
findings.name_usage = usage;
fs.mkdirSync(path.join(root, "build/l10n"), { recursive: true });
fs.writeFileSync(path.join(root, "build/l10n/findings.json"), JSON.stringify(findings, null, 1));
console.log("pairs", pairs.length, "unique", seen.size);
for (const k in findings) console.log(k, Array.isArray(findings[k]) ? findings[k].length : JSON.stringify(findings[k]));

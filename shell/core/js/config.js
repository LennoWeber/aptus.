.pragma library
// Settings logic (07-architecture §8, 10-settings, surfaces/settings.md §4): defaults, type and
// range validation, cross-key rules, serialisation of non-default values.

var VERSION = 2
// Renamed keys (07 §8): old key → new key. Applied on load; the file is then rewritten once.
var MIGRATIONS = {}

function notImplemented(name) { throw new Error("config." + name + ": not implemented") }

// key → default, with template keys expanded.
function defaults(schema) { notImplemented("defaults") }
// Validate one value: { ok: bool, value: normalised value, message: "…must be 0–6" }.
// Covers type, range, values, nullable, pattern, minItems/maxItems, unique, itemRanges and the
// insideHome rule (also every entry of a list<path>). home: for "~" expansion. exists(path): bool,
// for entries with mustExist (the shell passes a FileView-backed check; null skips it).
function validate(schema, key, value, home, exists) { notImplemented("validate") }
// The cross-key rules of schema.rules over a full value map: [{ key, message }] for the keys that
// must fall back to their default.
function crossCheck(schema, values) { notImplemented("crossCheck") }
// Apply MIGRATIONS to a raw key → value map. → { values, changed: bool }.
function migrate(raw) { notImplemented("migrate") }
// Parse settings.json text. → { ok, v1: bool, values, overrides, unknown, problems: [{key, message}],
// error: "line 3, column 7: …" }. A file without "v" is a v1 file: ignored, v1 = true.
function load(schema, text, home, exists) { notImplemented("load") }
// The settings.json text for these overrides and unknown keys ({"v": 2, …}, sorted keys, 2 spaces).
function serialise(overrides, unknown) { notImplemented("serialise") }
// Deep equality of two JSON values (default check).
function equal(a, b) { notImplemented("equal") }
// Whether the entry's visibleIf holds for these values (settings window).
function visible(entry, values) { notImplemented("visible") }

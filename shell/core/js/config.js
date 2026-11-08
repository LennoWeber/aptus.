.pragma library
// Settings logic (07-architecture §8, 10-settings, surfaces/settings.md §4): defaults, type and
// range validation, cross-key rules, serialisation of non-default values.

var VERSION = 2
// Renamed keys (07 §8): old key → new key. Applied on load; the file is then rewritten once.
var MIGRATIONS = {}
// The `time` type: "HH:MM", 24 h.
var TIME_RE = /^([01][0-9]|2[0-3]):[0-5][0-9]$/

// Invariants: wrong inputs are bugs in the caller, thrown as "config invariant: …".
function invariant(cond, message) { if (!cond) throw new Error("config invariant: " + message) }
function checkSchema(schema) {
    invariant(schema && typeof schema === "object" && schema.keys && typeof schema.keys === "object",
              "schema without keys")
    invariant(Array.isArray(schema.rules), "schema without rules")
}
// The file's maps never hold "v" (serialise writes it) and a key is either known or unknown.
function checkSerialise(overrides, unknown) {
    invariant(!("v" in overrides) && !("v" in unknown), "\"v\" inside the overrides or unknown keys")
    for (var k in overrides) invariant(!(k in unknown), k + " is both an override and unknown")
}

// Private helpers.
function isObj(v) { return v !== null && typeof v === "object" && !Array.isArray(v) }
function clone(v) { return v === undefined ? undefined : JSON.parse(JSON.stringify(v)) }
function expand(path, home) {
    if (typeof path !== "string") return path
    if (path === "~") return home
    return path.indexOf("~/") === 0 && home ? home + path.substr(1) : path
}
function insideHome(path, home) {
    if (!home) return true
    var p = expand(path, home)
    if (p.charAt(0) !== "/") return false
    // normalise "." and ".." segments
    var parts = [], segs = p.split("/")
    for (var i = 0; i < segs.length; i++) {
        if (segs[i] === "" || segs[i] === ".") continue
        if (segs[i] === "..") parts.pop(); else parts.push(segs[i])
    }
    var norm = "/" + parts.join("/")
    return norm === home || norm.indexOf(home.replace(/\/$/, "") + "/") === 0
}
function insideHomeTypes(schema) {
    for (var i = 0; i < (schema.rules || []).length; i++)
        if (schema.rules[i].kind === "insideHome") return schema.rules[i].types
    return []
}
function fail(msg) { return { ok: false, value: undefined, message: msg } }
function okv(v) { return { ok: true, value: v, message: "" } }
function checkInt(e, v, label) {
    if (typeof v !== "number" || !isFinite(v) || Math.floor(v) !== v) return label + " must be a whole number"
    if (v === 0 && e.zeroMeans) return ""
    if (e.min !== undefined && v < e.min || e.max !== undefined && v > e.max)
        return label + " must be " + e.min + "–" + e.max + (e.zeroMeans ? " or 0 (" + e.zeroMeans + ")" : "")
    return ""
}
function inValues(values, v) {
    for (var i = 0; i < values.length; i++) if (equal(values[i], v)) return true
    return false
}
function checkShapeField(type, v) {
    if (type === "string") return typeof v === "string"
    if (type === "number") return typeof v === "number" && isFinite(v)
    if (type === "time") return typeof v === "string" && TIME_RE.test(v)
    if (type === "list<int>") return Array.isArray(v) && v.every(function (x) { return typeof x === "number" && Math.floor(x) === x })
    return true
}
// The offset of the first syntax error in JSON text (the engine's JSON.parse reports none), and
// a short reason. A small recursive-descent scan; only runs after JSON.parse failed.
function locateError(t) {
    var i = 0
    function ws() { while (i < t.length && " \t\n\r".indexOf(t[i]) >= 0) i++ }
    function err(m) { throw { at: i, message: m } }
    function str() {
        i++
        while (i < t.length && t[i] !== '"') {
            if (t[i] === "\\") i++
            else if (t.charCodeAt(i) < 32) err("control character in text")
            i++
        }
        if (i >= t.length) err("unterminated text")
        i++
    }
    function lit() {
        var m = /^(true|false|null|-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?)/.exec(t.substr(i, 64))
        if (!m) err(i >= t.length ? "unexpected end" : "unexpected " + JSON.stringify(t[i]))
        i += m[0].length
    }
    function val() {
        ws()
        if (t[i] === "{") {
            i++; ws()
            if (t[i] === "}") { i++; return }
            for (;;) {
                ws(); if (t[i] !== '"') err("expected a quoted key"); str(); ws()
                if (t[i] !== ":") err("expected :"); i++; val(); ws()
                if (t[i] === ",") { i++; continue }
                if (t[i] === "}") { i++; return }
                err("expected , or }")
            }
        } else if (t[i] === "[") {
            i++; ws()
            if (t[i] === "]") { i++; return }
            for (;;) {
                val(); ws()
                if (t[i] === ",") { i++; continue }
                if (t[i] === "]") { i++; return }
                err("expected , or ]")
            }
        } else if (t[i] === '"') str()
        else lit()
    }
    try { val(); ws(); if (i < t.length) err("text after the end") } catch (e) { return e }
    return { at: 0, message: "parse error" }
}
// "line L, column C: reason" for invalid JSON text.
function errorPosition(text) {
    var e = locateError(text), line = 1, col = 1
    for (var i = 0; i < e.at && i < text.length; i++) { if (text[i] === "\n") { line++; col = 1 } else col++ }
    return "line " + line + ", column " + col + ": " + e.message
}
// JSON with sorted object keys (stable settings.json diffs).
function sortedStringify(v, indent, level) {
    var pad = Array(level + 1).join(indent), inner = pad + indent
    if (Array.isArray(v)) {
        if (!v.length) return "[]"
        return "[\n" + v.map(function (x) { return inner + sortedStringify(x, indent, level + 1) }).join(",\n") + "\n" + pad + "]"
    }
    if (isObj(v)) {
        var ks = Object.keys(v).sort()
        if (!ks.length) return "{}"
        return "{\n" + ks.map(function (k) { return inner + JSON.stringify(k) + ": " + sortedStringify(v[k], indent, level + 1) }).join(",\n") + "\n" + pad + "}"
    }
    return JSON.stringify(v)
}

// key → default, with template keys expanded.
function defaults(schema) {
    checkSchema(schema);
    var out = {}
    for (var k in schema.keys) out[k] = clone(schema.keys[k]["default"])
    return out
}
// Validate one value: { ok: bool, value: normalised value, message: "…must be 0–6" }.
// Covers type, range, values, nullable, pattern, minItems/maxItems, unique, itemRanges and the
// insideHome rule (also every entry of a list<path>). home: for "~" expansion. exists(path): bool,
// for entries with mustExist (the shell passes a FileView-backed check; null skips it).
function validate(schema, key, value, home, exists) {
    checkSchema(schema);
    var e = schema.keys[key]
    if (!e) return fail("unknown setting")
    var label = e.label || key
    if (value === null) return e.nullable ? okv(null) : fail(label + " cannot be empty")
    var ihTypes = insideHomeTypes(schema)
    var t = e.type
    switch (t) {
    case "derived":
        return fail(label + " is not settable")
    case "bool":
        return typeof value === "boolean" ? okv(value) : fail(label + " must be on or off")
    case "int": {
        var m = checkInt(e, value, label)
        return m ? fail(m) : okv(value)
    }
    case "enum":
        return inValues(e.values, value) ? okv(value) : fail(label + " must be one of " + e.values.join(", "))
    case "enum|int":
        if (inValues(e.values, value)) return okv(value)
        var mi = checkInt(e, value, label)
        return mi ? fail(label + " must be " + e.values.join(", ") + " or " + e.min + "–" + e.max) : okv(value)
    case "enum|string":
        if (inValues(e.values, value)) return okv(value)
        if (typeof value !== "string" || (e.pattern && value.indexOf(e.pattern) < 0))
            return fail(label + " must be one of " + e.values.join(", ") + " or a URL with " + e.pattern)
        return okv(value)
    case "string":
        if (typeof value !== "string") return fail(label + " must be text")
        if (e.pattern && value.indexOf(e.pattern) < 0) return fail(label + " must contain " + e.pattern)
        return okv(value)
    case "time":
        return typeof value === "string" && TIME_RE.test(value) ? okv(value) : fail(label + " must be a time like 07:30")
    case "path":
        if (typeof value !== "string" || value === "") return fail(label + " must be a path")
        if (ihTypes.indexOf("path") >= 0 && !insideHome(value, home)) return fail(label + " must be inside your home folder")
        if (e.mustExist && exists && !exists(expand(value, home))) return fail(label + " must be an existing folder")
        return okv(value)
    case "map": {
        if (!isObj(value)) return fail(label + " must be a table")
        for (var mk in value) {
            if (typeof value[mk] !== "string") return fail(label + ": " + mk + " must be text")
            if (e.pattern && value[mk].indexOf(e.pattern) < 0) return fail(label + ": " + mk + " must contain " + e.pattern)
        }
        return okv(value)
    }
    case "object": {
        if (!isObj(value)) return fail(label + " must be an object")
        for (var sk in e.shape || {}) {
            if (!(sk in value) || !checkShapeField(e.shape[sk], value[sk])) return fail(label + ": " + sk + " is missing or wrong")
            var ir = e.itemRanges && e.itemRanges[sk]
            if (ir && Array.isArray(value[sk])) {
                var seen = {}
                for (var q = 0; q < value[sk].length; q++) {
                    var iv = value[sk][q]
                    if (iv < ir.min || iv > ir.max) return fail(label + ": " + sk + " must be " + ir.min + "–" + ir.max)
                    if (ir.unique && seen[iv]) return fail(label + ": " + sk + " lists " + iv + " twice")
                    seen[iv] = true
                }
            }
        }
        return okv(value)
    }
    case "list": {
        if (!Array.isArray(value)) return fail(label + " must be a list")
        if (e.minItems !== undefined && value.length < e.minItems || e.maxItems !== undefined && value.length > e.maxItems)
            return fail(label + " must have " + (e.minItems === e.maxItems ? e.minItems : (e.minItems || 0) + "–" + e.maxItems) + " entries")
        var seenL = []
        for (var i = 0; i < value.length; i++) {
            var it = value[i]
            if (e.of === "string" && typeof it !== "string") return fail(label + " must list text")
            if (e.of === "enum" && !inValues(e.values, it)) return fail(label + ": " + it + " is not one of " + e.values.join(", "))
            if (e.of === "int") { var mm = checkInt(e, it, label); if (mm) return fail(mm) }
            if (e.of === "path") {
                if (typeof it !== "string" || it === "") return fail(label + " must list paths")
                if (ihTypes.indexOf("list<path>") >= 0 && !insideHome(it, home)) return fail(label + ": " + it + " must be inside your home folder")
            }
            if (e.unique) {
                for (var u = 0; u < seenL.length; u++) if (equal(seenL[u], it)) return fail(label + " lists " + it + " twice")
                seenL.push(it)
            }
        }
        return okv(value)
    }
    }
    return fail(label + ": unknown type " + t)
}
// The cross-key rules of schema.rules over a full value map: [{ key, message }] for the keys that
// must fall back to their default.
function crossCheck(schema, values) {
    checkSchema(schema);
    var out = []
    for (var i = 0; i < (schema.rules || []).length; i++) {
        var r = schema.rules[i]
        if (r.kind === "order") {
            // keys[i] relation keys[i+1]; zeros (never) are skipped when ignoreZero
            var prevKey = null
            for (var j = 0; j < r.keys.length; j++) {
                var k = r.keys[j], v = values[k]
                if (r.ignoreZero && v === 0) continue
                if (prevKey !== null) {
                    var rel = r.relations[Math.min(j - 1, r.relations.length - 1)]
                    var pv = values[prevKey]
                    var ok = rel === "<" ? pv < v : pv <= v
                    if (!ok) out.push({ key: k, message: (schema.keys[k].label || k) + " must be "
                                        + (rel === "<" ? "later than " : "at least ") + (schema.keys[prevKey].label || prevKey) })
                }
                prevKey = k
            }
        } else if (r.kind === "member") {
            var list = values[r.of]
            if (Array.isArray(list) && list.indexOf(values[r.key]) < 0)
                out.push({ key: r.key, message: (schema.keys[r.key].label || r.key) + " must be one of " + list.join(", ") })
        }
    }
    return out
}
// Apply MIGRATIONS to a raw key → value map. → { values, changed: bool }.
function migrate(raw) {
    var out = {}, changed = false
    for (var k in raw) {
        if (MIGRATIONS[k] && !(MIGRATIONS[k] in raw)) { out[MIGRATIONS[k]] = raw[k]; changed = true }
        else out[k] = raw[k]
    }
    return { values: out, changed: changed }
}
// Parse settings.json text. → { ok, v1: bool, migrated: bool, values, overrides, unknown,
// problems: [{key, message}], error: "line 3, column 7: …" }. A file without "v" is a v1 file:
// ignored, v1 = true. migrated: MIGRATIONS renamed a key (Config rewrites the file once, 07 §8).
// A derived key in the file is a problem ("not settable"); derived values follow their source.
function load(schema, text, home, exists) {
    checkSchema(schema); invariant(typeof text === "string", "settings text is not a string");
    var res = { ok: true, v1: false, values: defaults(schema), overrides: {}, unknown: {}, problems: [], error: "", migrated: false }
    if (text === undefined || text === null || String(text).trim() === "") return res
    var raw
    try { raw = JSON.parse(text) } catch (e) { res.ok = false; res.error = errorPosition(String(text)); return res }
    if (!isObj(raw)) { res.ok = false; res.error = "settings.json must be an object"; return res }
    if (!("v" in raw)) { res.v1 = true; return res }
    delete raw.v
    var mig = migrate(raw)
    res.migrated = mig.changed
    raw = mig.values
    for (var k in raw) {
        if (!(k in schema.keys)) { res.unknown[k] = raw[k]; continue }
        var r = validate(schema, k, raw[k], home, exists)
        if (!r.ok) { res.problems.push({ key: k, message: r.message }); continue }
        if (!equal(r.value, schema.keys[k]["default"])) res.overrides[k] = r.value
        res.values[k] = r.value
    }
    deriveAll(schema, res.values)
    var cross = crossCheck(schema, res.values)
    for (var c = 0; c < cross.length; c++) {
        res.problems.push(cross[c])
        res.values[cross[c].key] = clone(schema.keys[cross[c].key]["default"])
        delete res.overrides[cross[c].key]
    }
    return res
}
// The settings.json text for these overrides and unknown keys ({"v": 2, …}, sorted keys, 2 spaces).
function serialise(overrides, unknown) {
    checkSerialise(overrides, unknown);
    var all = {}
    for (var u in unknown || {}) all[u] = unknown[u]
    for (var o in overrides || {}) all[o] = overrides[o]
    var ks = Object.keys(all).sort()
    var lines = ["  \"v\": " + VERSION]
    for (var i = 0; i < ks.length; i++) lines.push("  " + JSON.stringify(ks[i]) + ": " + sortedStringify(all[ks[i]], "  ", 1))
    return "{\n" + lines.join(",\n") + "\n}\n"
}
// Deep equality of two JSON values (default check).
function equal(a, b) {
    if (a === b) return true
    if (typeof a !== typeof b || a === null || b === null) return false
    if (Array.isArray(a)) {
        if (!Array.isArray(b) || a.length !== b.length) return false
        for (var i = 0; i < a.length; i++) if (!equal(a[i], b[i])) return false
        return true
    }
    if (typeof a === "object") {
        var ka = Object.keys(a), kb = Object.keys(b)
        if (ka.length !== kb.length) return false
        for (var j = 0; j < ka.length; j++) if (!equal(a[ka[j]], b[ka[j]])) return false
        return true
    }
    return false
}
// Whether the entry's visibleIf holds for these values (settings window).
function visible(entry, values) {
    var c = entry.visibleIf
    if (!c) return true
    var v = values[c.key]
    if ("equals" in c) return equal(v, c.equals)
    if ("notEquals" in c) return !equal(v, c.notEquals)
    return true
}
// Fill the derived keys (bar.height ← appearance.textScale): the derived entry's values[i] for
// the source's values[i]. Config runs it after load and after every set.
function deriveAll(schema, values) {
    checkSchema(schema);
    for (var k in schema.keys) {
        var e = schema.keys[k]
        if (e.type !== "derived") continue
        var src = schema.keys[e.from]
        var i = src && src.values ? src.values.indexOf(values[e.from]) : -1
        values[k] = i >= 0 && i < e.values.length ? e.values[i] : e["default"]
    }
}

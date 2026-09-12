// Pure logic for the notch island: no Qt, no I/O, so it runs under node for
// tests and under QML's JavaScript engine unchanged.

var DEFAULTS = {
  notchWidth: 184,
  notchHeight: 32,
  hoverDelay: 120,
  leaveDelay: 350,
  osdDuration: 1200,
  eventDuration: 3200,
  notificationDuration: 4500,
  visualizer: "auto",       // auto | cava | fake | off
  notifications: true,
  statusFlashes: true,
  batteryEvents: true,
  airpods: true,
  scrollVolume: true,
  clock24: false,
  lowBatteryLevels: [20, 10]
}

var STATES = ["idle", "compact", "event", "expanded", "calibrate"]

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value))
}

function intOr(value, fallback) {
  var n = parseInt(value, 10)
  return isFinite(n) ? n : fallback
}

function resolveSettings(entry) {
  var out = {}
  for (var k in DEFAULTS) out[k] = DEFAULTS[k]
  if (!entry || typeof entry !== "object") return out
  for (var key in entry) {
    if (key === "id" || !(key in DEFAULTS)) continue
    var v = entry[key]
    if (typeof DEFAULTS[key] === "number") {
      var n = Number(v)
      if (isFinite(n)) out[key] = n
    } else if (typeof DEFAULTS[key] === "boolean") {
      out[key] = v === true
    } else if (Array.isArray(DEFAULTS[key])) {
      if (Array.isArray(v)) out[key] = v.map(Number).filter(isFinite)
    } else if (v !== undefined && v !== null) {
      out[key] = String(v)
    }
  }
  out.notchWidth = clamp(Math.round(out.notchWidth), 60, 800)
  out.notchHeight = clamp(Math.round(out.notchHeight), 12, 120)
  return out
}

// ----------------------------------------------------------------- OSD

// Same icon names as the stock omarchy.osd so scripts keep working, drawn
// with the Material glyphs the bar's audio widget uses (the stock OSD's Font
// Awesome range is missing from non-Nerd shell fonts such as SF Pro).
var widestIcon = "󰕾"

function iconFor(name, percent) {
  var n = String(name || "").toLowerCase()
  if (n === "volume-muted" || n === "volume-mute" || n === "muted" || n === "mute") return "󰖁"
  if (n === "volume-low") return "󰕿"
  if (n === "volume-medium") return "󰖀"
  if (n === "volume-high" || n === "volume") return "󰕾"
  if (n === "microphone-muted" || n === "microphone-off" || n === "mic-muted" || n === "mic-off") return "󰍭"
  if (n === "microphone" || n === "mic") return "󰍬"
  if (n === "keyboard") return "󰌌"
  if (n === "brightness" || n === "display") return "󰍹"
  if (n === "touchpad") return "󰟸"
  if (n === "touch" || n === "touchscreen") return "󰝁"
  if (n === "reboot" || n === "restart") return "󰜉"
  if (n === "shutdown" || n === "power" || n === "poweroff") return "󰐥"
  if (n === "logout" || n === "sign-out" || n === "leave") return "󰍃"
  if (n === "media" || n === "player") return "󰝚"
  if (n === "media-source" || n === "player-source") return "󰝚"
  if (n === "media-play" || n === "player-play") return "󰐊"
  if (n === "media-pause" || n === "player-pause") return "󰏤"
  if (n === "media-next" || n === "player-next") return "󰒭"
  if (n === "media-previous" || n === "player-previous") return "󰒮"
  if (n.length > 0) return name
  if (percent <= 0) return "󰖁"
  if (percent <= 33) return "󰕿"
  if (percent <= 66) return "󰖀"
  return "󰕾"
}

function isMediaIconKey(iconKey) {
  var k = String(iconKey || "")
  return k.indexOf("media") === 0 || k.indexOf("player") === 0
}

function isMicIconKey(iconKey) {
  var k = String(iconKey || "")
  return k.indexOf("microphone") === 0 || k.indexOf("mic") === 0
}

function osdEventFromPayload(payloadJson, defaultDuration) {
  var p
  try { p = JSON.parse(payloadJson || "{}") } catch (e) { p = {} }
  if (!p || typeof p !== "object") p = {}
  var iconName = p.icon || ""
  var rawMessage = p.message || ""
  var rawValue = p.value === undefined ? "" : String(p.value)
  var rawMax = p.max === undefined || p.max === "" ? "100" : String(p.max)
  var rawDuration = p.duration === undefined || p.duration === "" ? "" : String(p.duration)

  var maxValue = Math.max(1, intOr(rawMax, 100))
  var parsedValue = parseInt(rawValue || "0", 10)
  var hasProgress = rawValue !== "" && !isNaN(parsedValue) && rawMessage === ""
  var value = hasProgress ? clamp(parsedValue, 0, maxValue) : 0
  var percent = hasProgress ? Math.round(value * 100 / maxValue) : -1
  var duration = rawDuration === "" ? (defaultDuration || DEFAULTS.osdDuration) : Math.max(0, intOr(rawDuration, DEFAULTS.osdDuration))
  var iconKey = String(iconName || "").toLowerCase()

  return {
    kind: "osd",
    iconKey: iconKey,
    icon: iconFor(iconName, percent),
    hasProgress: hasProgress,
    value: value,
    max: maxValue,
    percent: percent,
    message: String(rawMessage || (hasProgress ? (p.progressText || percent + "%") : "")),
    media: isMediaIconKey(iconKey),
    duration: duration
  }
}

// --------------------------------------------------------------- events

// Which state the island should be in. Higher entries win.
function resolveState(ctx) {
  if (ctx.calibrating) return "calibrate"
  if (ctx.event && ctx.expanded && ctx.event.kind === "osd") return "expanded"
  if (ctx.event) return "event"
  if (ctx.expanded) return "expanded"
  if (ctx.mediaPlaying) return "compact"
  return "idle"
}

// Merge a new event into the queue. OSDs are live feedback for a key the
// user is holding, so they never wait: a queued OSD is replaced in place and
// a showing OSD is updated. Other events line up, newest last, capped so a
// burst of notifications cannot hold the island for a minute.
function enqueue(current, queue, event, maxQueued) {
  var cap = maxQueued || 3
  var next = queue.slice()
  if (event.kind === "osd") {
    if (current && current.kind === "osd") return { current: event, queue: next, replaced: true }
    next = next.filter(function(e) { return e.kind !== "osd" })
    next.unshift(event)
    return { current: current, queue: next, replaced: false }
  }
  // A flash for the same key supersedes its own pending sibling (caps lock
  // tapped twice) rather than showing two stale states in a row.
  next = next.filter(function(e) { return !(e.kind === event.kind && e.key && e.key === event.key) })
  if (current && current.kind === event.kind && current.key && current.key === event.key)
    return { current: event, queue: next, replaced: true }
  next.push(event)
  while (next.length > cap) next.shift()
  return { current: current, queue: next, replaced: false }
}

function batteryIcon(percent, charging) {
  if (charging) return "󰂄"
  var p = clamp(Math.round(percent), 0, 100)
  var glyphs = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
  return glyphs[Math.round(p / 10)]
}

function formatDuration(seconds) {
  var s = Math.max(0, Math.round(Number(seconds) || 0))
  if (s === 0) return ""
  var h = Math.floor(s / 3600)
  var m = Math.round((s % 3600) / 60)
  if (h === 0) return m + "m"
  if (m === 0) return h + "h"
  return h + "h " + m + "m"
}

function formatClock(seconds) {
  var s = Math.max(0, Math.floor(Number(seconds) || 0))
  var m = Math.floor(s / 60)
  var r = s % 60
  return m + ":" + (r < 10 ? "0" : "") + r
}

// Charger plugged in or pulled: one card either way.
function powerSourceEvent(onBattery, percent, timeSeconds, duration) {
  var p = clamp(Math.round(percent), 0, 100)
  var remaining = formatDuration(timeSeconds)
  return {
    kind: "battery",
    key: "power",
    icon: batteryIcon(p, !onBattery),
    title: onBattery ? "On Battery" : "Charging",
    message: p + "%" + (remaining ? (onBattery ? " · " + remaining + " left" : " · " + remaining + " to full") : ""),
    percent: p,
    charging: !onBattery,
    urgent: false,
    duration: duration || DEFAULTS.eventDuration
  }
}

// Fires once per threshold on the way down; charging clears the slate.
function lowBatteryCheck(percent, onBattery, levels, warned) {
  var p = Math.round(percent)
  var seen = warned || []
  if (!onBattery) return { event: null, warned: [] }
  for (var i = 0; i < levels.length; i++) {
    var level = levels[i]
    if (p <= level && seen.indexOf(level) === -1) {
      return {
        event: {
          kind: "battery",
          key: "low",
          icon: batteryIcon(p, false),
          title: "Low Battery",
          message: p + "% remaining",
          percent: p,
          charging: false,
          urgent: true,
          duration: DEFAULTS.eventDuration + 1500
        },
        warned: seen.concat([level])
      }
    }
  }
  return { event: null, warned: seen }
}

function parsePod(raw) {
  var r = raw && typeof raw === "object" ? raw : {}
  return {
    available: r.available === true,
    level: r.available === true ? clamp(intOr(r.level, 0), 0, 100) : -1,
    charging: r.charging === true
  }
}

function parseAirpods(raw) {
  var text = String(raw || "").trim()
  if (!text) return null
  var parsed
  try { parsed = JSON.parse(text) } catch (e) { return null }
  if (!parsed || typeof parsed !== "object") return null
  return {
    connected: parsed.connected === true,
    name: String(parsed.device_name || "AirPods"),
    model: String(parsed.model_name || ""),
    isHeadset: parsed.is_headset === true,
    left: parsePod(parsed.left),
    right: parsePod(parsed.right),
    caseBattery: parsePod(parsed["case"]),
    headset: parsePod(parsed.headset)
  }
}

function airpodsEvent(status, duration) {
  if (!status) return null
  var parts = []
  if (status.isHeadset) {
    if (status.headset.level >= 0) parts.push(status.headset.level + "%")
  } else {
    if (status.left.level >= 0) parts.push("L " + status.left.level + "%")
    if (status.right.level >= 0) parts.push("R " + status.right.level + "%")
    if (status.caseBattery.level >= 0) parts.push("Case " + status.caseBattery.level + "%")
  }
  return {
    kind: "airpods",
    key: "connect",
    icon: "󰋋",
    title: status.name || "AirPods",
    message: parts.length ? parts.join("  ") : "Connected",
    pods: status,
    duration: duration || DEFAULTS.eventDuration
  }
}

function notificationEvent(row, duration) {
  var r = row || {}
  var summary = String(r.summary || "").trim()
  var body = String(r.body || "").replace(/<[^>]+>/g, "").replace(/\s+/g, " ").trim()
  var app = String(r.app || "").trim()
  return {
    kind: "notification",
    key: "",
    app: app,
    appIcon: String(r.appIcon || ""),
    image: String(r.image || ""),
    glyph: String(r.glyph || ""),
    title: summary || app || "Notification",
    message: body || (summary ? app : ""),
    urgent: r.urgency === 2,
    duration: duration || DEFAULTS.notificationDuration
  }
}

var FLASHES = {
  capslock: { on: "󰪛", off: "󰪛", label: "Caps Lock" },
  mic: { on: "󰍬", off: "󰍭", label: "Microphone", onText: "Microphone on", offText: "Microphone muted" },
  recording: { on: "󰻂", off: "󰻂", label: "Screen Recording", onText: "Recording started", offText: "Recording stopped" },
  dnd: { on: "󰂛", off: "󰂚", label: "Do Not Disturb" },
  nightlight: { on: "󰖔", off: "󰖨", label: "Night Light" },
  stayawake: { on: "󰅶", off: "󰾫", label: "Stay Awake" },
  layout: { on: "󰌌", off: "󰌌", label: "Keyboard" }
}

function flashEvent(key, on, detail, duration) {
  var spec = FLASHES[key]
  if (!spec) return null
  var text
  if (key === "layout") text = detail || "Layout changed"
  else if (on && spec.onText) text = spec.onText
  else if (!on && spec.offText) text = spec.offText
  else text = spec.label + (on ? " on" : " off")
  return {
    kind: "flash",
    key: key,
    icon: on ? spec.on : spec.off,
    active: !!on,
    title: text,
    message: "",
    duration: duration || 1500
  }
}

// Hyprland's activelayout event carries "KEYBOARD,LAYOUT NAME".
function layoutFromEvent(data) {
  var text = String(data || "")
  var comma = text.indexOf(",")
  if (comma === -1) return ""
  var name = text.slice(comma + 1).trim()
  var kb = text.slice(0, comma)
  if (kb.indexOf("hl-virtual-keyboard") === 0) return ""
  return name
}

// ----------------------------------------------------------- visualizer

// cava's raw ascii output: "12;40;7;...;\n" with values in 0..ascii_max_range.
function parseCavaLine(line, bars, maxRange) {
  var range = maxRange || 100
  var out = []
  var parts = String(line || "").split(";")
  for (var i = 0; i < bars; i++) {
    var n = parseInt(parts[i], 10)
    out.push(isFinite(n) ? clamp(n / range, 0, 1) : 0)
  }
  return out
}

// A gentle stand-in when cava is not installed: overlapping sines so the
// bars drift rather than flicker.
function fakeBars(tSeconds, bars) {
  var out = []
  for (var i = 0; i < bars; i++) {
    var a = Math.sin(tSeconds * 5.1 + i * 1.7)
    var b = Math.sin(tSeconds * 3.3 + i * 0.9 + 1.2)
    var c = Math.sin(tSeconds * 7.7 + i * 2.3)
    out.push(clamp(0.25 + 0.2 * a + 0.2 * b + 0.15 * c, 0.08, 1))
  }
  return out
}

function visualizerMode(setting, cavaAvailable) {
  var s = String(setting || "auto")
  if (s === "off") return "off"
  if (s === "fake") return "fake"
  if (s === "cava") return cavaAvailable ? "cava" : "fake"
  return cavaAvailable ? "cava" : "fake"
}

function cavaConfig(bars, framerate) {
  return [
    "[general]",
    "bars = " + bars,
    "framerate = " + (framerate || 30),
    "autosens = 1",
    "sensitivity = 200",
    "[input]",
    "method = pipewire",
    "source = auto",
    "[output]",
    "method = raw",
    "raw_target = /dev/stdout",
    "data_format = ascii",
    "ascii_max_range = 100",
    "bar_delimiter = 59",
    "frame_delimiter = 10",
    "[smoothing]",
    "noise_reduction = 70",
    ""
  ].join("\n")
}

// ------------------------------------------------------------ geometry

// Everything is measured out from the notch so the island always grows
// symmetrically around the camera. Widths are content-driven; heights are
// fixed per state so transitions don't jitter as text changes.
function islandSize(state, s, content) {
  var w = s.notchWidth
  var h = s.notchHeight
  var c = content || {}
  var wing = Math.round(h * 1.15)
  if (state === "compact") {
    return { width: w + 2 * wing + 8, height: h, radius: Math.round(h * 0.45) }
  }
  if (state === "event") {
    var kind = c.kind || "osd"
    if (kind === "osd") {
      var side = c.hasProgress ? Math.max(wing + 8, Math.round(h * 3.6)) : Math.max(wing + 8, Math.round(c.textWidth || 0) + 2 * (c.pad || 12))
      return { width: w + 2 * side, height: h, radius: Math.round(h * 0.45) }
    }
    if (kind === "notification") {
      var nh = Math.round(h * 2.4)
      return { width: Math.max(w + 2 * wing, Math.round(w * 2.2)), height: nh, radius: Math.round(nh * 0.42) }
    }
    if (kind === "flash") {
      var fs = Math.max(wing + 8, Math.round(c.textWidth || 0) + 2 * (c.pad || 12))
      return { width: w + 2 * fs, height: h, radius: Math.round(h * 0.45) }
    }
    var es = Math.max(wing + 8, Math.round(c.textWidth || 0) + 2 * (c.pad || 12))
    return { width: w + 2 * es, height: h, radius: Math.round(h * 0.45) }
  }
  if (state === "expanded") {
    var mode = c.mode || "dashboard"
    var eh = mode === "media" ? Math.round(h * 4.3) : Math.round(h * 3.0)
    return { width: Math.max(w + 2 * wing * 2, Math.round(w * 2.15)), height: eh, radius: Math.round(h * 0.7) }
  }
  if (state === "calibrate") {
    return { width: w, height: h, radius: Math.round(h * 0.45) }
  }
  return { width: w, height: h, radius: Math.round(h * 0.45) }
}

var CAL_KEYS = { left: 16777234, right: 16777236, up: 16777235, down: 16777237, enter: 16777220, ret: 16777221, escape: 16777216 }

function calibrationStep(keyCode, shift, s) {
  var step = shift ? 10 : 2
  var next = { notchWidth: s.notchWidth, notchHeight: s.notchHeight, action: "" }
  if (keyCode === CAL_KEYS.left) next.notchWidth -= step
  else if (keyCode === CAL_KEYS.right) next.notchWidth += step
  else if (keyCode === CAL_KEYS.up) next.notchHeight -= (shift ? 4 : 1)
  else if (keyCode === CAL_KEYS.down) next.notchHeight += (shift ? 4 : 1)
  else if (keyCode === CAL_KEYS.enter || keyCode === CAL_KEYS.ret) next.action = "save"
  else if (keyCode === CAL_KEYS.escape) next.action = "cancel"
  else return null
  next.notchWidth = clamp(next.notchWidth, 60, 800)
  next.notchHeight = clamp(next.notchHeight, 12, 120)
  return next
}

// Where the plugin's settings live in shell.json: the plugins[] entry with
// our id. Returns a mutator suitable for shell.mutateShellConfig.
function settingsMutator(pluginId, patch) {
  return function(config) {
    if (!Array.isArray(config.plugins)) config.plugins = []
    var entry = null
    for (var i = 0; i < config.plugins.length; i++) {
      if (config.plugins[i] && config.plugins[i].id === pluginId) { entry = config.plugins[i]; break }
    }
    if (!entry) { entry = { id: pluginId }; config.plugins.push(entry) }
    for (var k in patch) entry[k] = patch[k]
  }
}

function pluginEntry(config, pluginId) {
  var plugins = config && Array.isArray(config.plugins) ? config.plugins : []
  for (var i = 0; i < plugins.length; i++)
    if (plugins[i] && String(plugins[i].id || "") === pluginId) return plugins[i]
  return null
}

// Qt's "h" only goes 12-hour when the format also carries AM/PM, so the
// 12-hour face is built by hand: the digits large, the meridiem small.
function clockParts(hours, minutes, clock24) {
  var h = Number(hours) || 0
  var m = Number(minutes) || 0
  var mm = (m < 10 ? "0" : "") + m
  if (clock24) return { time: (h < 10 ? "0" : "") + h + ":" + mm, suffix: "" }
  var twelve = h % 12
  if (twelve === 0) twelve = 12
  return { time: twelve + ":" + mm, suffix: h < 12 ? "AM" : "PM" }
}

function mediaSubtitle(artist, album, app) {
  var parts = []
  if (artist) parts.push(artist)
  if (album && album !== artist) parts.push(album)
  if (!parts.length && app) parts.push(app)
  return parts.join(" · ")
}

function progressFraction(position, length) {
  var len = Number(length) || 0
  if (len <= 0) return 0
  return clamp((Number(position) || 0) / len, 0, 1)
}

if (typeof module !== "undefined") {
  module.exports = {
    DEFAULTS: DEFAULTS,
    STATES: STATES,
    FLASHES: FLASHES,
    CAL_KEYS: CAL_KEYS,
    widestIcon: widestIcon,
    clamp: clamp,
    resolveSettings: resolveSettings,
    iconFor: iconFor,
    isMediaIconKey: isMediaIconKey,
    isMicIconKey: isMicIconKey,
    osdEventFromPayload: osdEventFromPayload,
    resolveState: resolveState,
    enqueue: enqueue,
    batteryIcon: batteryIcon,
    formatDuration: formatDuration,
    formatClock: formatClock,
    powerSourceEvent: powerSourceEvent,
    lowBatteryCheck: lowBatteryCheck,
    parseAirpods: parseAirpods,
    airpodsEvent: airpodsEvent,
    notificationEvent: notificationEvent,
    flashEvent: flashEvent,
    layoutFromEvent: layoutFromEvent,
    parseCavaLine: parseCavaLine,
    fakeBars: fakeBars,
    visualizerMode: visualizerMode,
    cavaConfig: cavaConfig,
    islandSize: islandSize,
    calibrationStep: calibrationStep,
    settingsMutator: settingsMutator,
    pluginEntry: pluginEntry,
    clockParts: clockParts,
    mediaSubtitle: mediaSubtitle,
    progressFraction: progressFraction
  }
}

.pragma library

function boundedInteger(value, fallback, min, max) {
  var n = parseInt(value, 10)
  if (isNaN(n)) n = fallback
  if (n < min) return min
  if (n > max) return max
  return n
}

function parseJson(text, fallback) {
  try {
    return JSON.parse(String(text || ""))
  } catch (e) {
    return fallback
  }
}

function parseStatus(text) {
  var status = parseJson(text, {})
  if (!status || typeof status !== "object") status = {}
  var encoder = status.encoder && typeof status.encoder === "object" ? status.encoder : {}
  return {
    running: status.running === true,
    monitor: String(status.monitor || ""),
    configuredMonitor: String(status.configuredMonitor || ""),
    seconds: boundedInteger(status.seconds, 60, minSeconds(), maxSeconds()),
    audio: normalizeAudio(status.audio),
    pid: String(status.pid || ""),
    ipc: String(status.ipc || ""),
    outputDir: String(status.outputDir || ""),
    lastClip: String(status.lastClip || ""),
    phase: String(status.phase || (status.running === true ? "live" : "off")),
    armed: status.armed === true || status.phase === "armed",
    linger: status.linger === true || status.phase === "linger",
    subject: String(status.subject || ""),
    region: String(status.region || ""),
    pinAddress: String(status.pinAddress || ""),
    mode: normalizeMode(status.mode),
    filter: normalizeFilter(status.filter),
    captureExtent: normalizeCaptureExtent(status.captureExtent),
    matchList: stringList(status.matchList),
    blacklist: stringList(status.blacklist),
    encoder: parseEncoder(encoder)
  }
}

function parseEncoder(encoder) {
  if (!encoder || typeof encoder !== "object") encoder = {}
  return {
    codec: normalizeCodec(encoder.codec),
    fps: boundedInteger(encoder.fps, 60, minFps(), maxFps()),
    quality: boundedInteger(encoder.quality, 40000, minQuality(), maxQuality()),
    cursor: encoder.cursor !== false,
    framerateMode: normalizeFramerateMode(encoder.framerateMode),
    bitrateMode: normalizeBitrateMode(encoder.bitrateMode)
  }
}

function parseWindows(text) {
  var rows = parseJson(text, [])
  if (!Array.isArray(rows)) return []
  var out = []
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    if (!row) continue
    var klass = String(row.class || row.initialClass || "")
    if (!klass) continue
    out.push({
      className: klass,
      initialClass: String(row.initialClass || klass),
      title: String(row.title || ""),
      monitor: String(row.monitor || ""),
      address: String(row.address || ""),
      focused: row.focused === true
    })
  }
  return out
}

function parseMonitors(text) {
  var rows = parseJson(text, [])
  if (!Array.isArray(rows)) return []
  var out = []
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    if (!row || !row.name) continue
    out.push({
      name: String(row.name),
      size: String(row.size || ""),
      focused: row.focused === true
    })
  }
  return out
}

function normalizeAudio(value) {
  var audio = String(value || "desktop")
  if (audio === "none" || audio === "desktop" || audio === "both") return audio
  return "desktop"
}

function normalizeMode(value) {
  var mode = String(value || "monitor")
  if (mode === "monitor" || mode === "follow" || mode === "pin" || mode === "region") return mode
  return "monitor"
}

function normalizeFilter(value) {
  var filter = String(value || "all")
  if (filter === "all" || filter === "allowlist" || filter === "denylist") return filter
  return "all"
}

function normalizeCaptureExtent(value) {
  var extent = String(value || "monitor")
  if (extent === "monitor" || extent === "window") return extent
  return "monitor"
}

function normalizeCodec(value) {
  var codec = String(value || "auto")
  if (codec === "auto" || codec === "h264" || codec === "hevc" || codec === "av1" || codec === "vp8" || codec === "vp9") return codec
  return "auto"
}

function normalizeFramerateMode(value) {
  return String(value || "cfr") === "vfr" ? "vfr" : "cfr"
}

function normalizeBitrateMode(value) {
  return String(value || "cbr") === "vbr" ? "vbr" : "cbr"
}

function stringList(value) {
  if (typeof value === "string") {
    if (!value) return []
    value = value.split(",")
  }
  if (!Array.isArray(value)) return []
  var out = []
  for (var i = 0; i < value.length; i++) {
    var item = String(value[i] || "").trim()
    if (item) out.push(item)
  }
  return out
}

function defaultBlacklist() {
  return ["waybar", "walker", "hyprlock"]
}

function encodeList(value) {
  return stringList(value).join(",")
}

function moveListItem(value, index, delta) {
  var list = stringList(value)
  var next = index + delta
  if (index < 0 || index >= list.length || next < 0 || next >= list.length) return list
  var item = list[index]
  list[index] = list[next]
  list[next] = item
  return list
}

function replaceListItem(value, index, text) {
  var list = stringList(value)
  var item = String(text || "").trim()
  if (index < 0 || index >= list.length) return list
  if (!item) list.splice(index, 1)
  else list[index] = item
  return list
}

function appendListItem(value, text) {
  var list = stringList(value)
  var item = String(text || "").trim()
  if (item) list.push(item)
  return list
}

function monitorOptions(monitors) {
  var options = [{ value: "", label: "Focused monitor" }]
  for (var i = 0; i < monitors.length; i++) {
    var monitor = monitors[i]
    var label = monitor.name
    if (monitor.size) label += " · " + monitor.size
    if (monitor.focused) label += " (focused)"
    options.push({ value: monitor.name, label: label })
  }
  return options
}

function minSeconds() { return 15 }
function maxSeconds() { return 7200 }
function minFps() { return 1 }
function maxFps() { return 240 }
function minQuality() { return 1 }
function maxQuality() { return 200000 }

function secondsOptions() {
  return [
    { value: "15", label: "15 seconds" },
    { value: "30", label: "30 seconds" },
    { value: "45", label: "45 seconds" },
    { value: "60", label: "1 minute" },
    { value: "120", label: "2 minutes" },
    { value: "180", label: "3 minutes" },
    { value: "300", label: "5 minutes" },
    { value: "600", label: "10 minutes" },
    { value: "900", label: "15 minutes" },
    { value: "1200", label: "20 minutes" },
    { value: "1800", label: "30 minutes" },
    { value: "2700", label: "45 minutes" },
    { value: "3600", label: "1 hour" },
    { value: "5400", label: "90 minutes" },
    { value: "7200", label: "2 hours" }
  ]
}

function formatReplayLength(seconds) {
  var n = boundedInteger(seconds, 60, minSeconds(), maxSeconds())
  var options = secondsOptions()
  for (var i = 0; i < options.length; i++) {
    if (parseInt(options[i].value, 10) === n) return options[i].label
  }
  if (n < 60) return n + " seconds"
  if (n % 3600 === 0) {
    var hours = n / 3600
    return hours === 1 ? "1 hour" : hours + " hours"
  }
  if (n % 60 === 0) return (n / 60) + " minutes"
  return n + " seconds"
}

function audioOptions() {
  return [
    { value: "none", label: "No audio" },
    { value: "desktop", label: "Desktop audio" },
    { value: "both", label: "Desktop + microphone" }
  ]
}

function codecOptions() {
  return [
    { value: "auto", label: "Auto" },
    { value: "h264", label: "H.264" },
    { value: "hevc", label: "HEVC" },
    { value: "av1", label: "AV1" },
    { value: "vp8", label: "VP8" },
    { value: "vp9", label: "VP9" }
  ]
}

function fpsOptions() {
  return [
    { value: "24", label: "24 fps" },
    { value: "30", label: "30 fps" },
    { value: "60", label: "60 fps" },
    { value: "120", label: "120 fps" },
    { value: "144", label: "144 fps" },
    { value: "165", label: "165 fps" },
    { value: "240", label: "240 fps" }
  ]
}

function qualityOptions() {
  return [
    { value: "10000", label: "10 Mbps" },
    { value: "20000", label: "20 Mbps" },
    { value: "40000", label: "40 Mbps" },
    { value: "60000", label: "60 Mbps" },
    { value: "80000", label: "80 Mbps" },
    { value: "100000", label: "100 Mbps" }
  ]
}

function framerateModeOptions() {
  return [
    { value: "cfr", label: "Constant (CFR)" },
    { value: "vfr", label: "Variable (VFR)" }
  ]
}

function bitrateModeOptions() {
  return [
    { value: "cbr", label: "Constant (CBR)" },
    { value: "vbr", label: "Variable (VBR)" }
  ]
}

function statusLabel(status) {
  if (!status) return "Buffer off"
  if (status.phase === "armed" || status.armed === true) return "Armed"
  if (status.phase === "linger" || status.linger === true) {
    var lingerMon = status.monitor || "monitor"
    return "Linger · " + lingerMon
  }
  if (status.running !== true) return "Buffer off"
  var monitor = status.monitor || "monitor"
  return monitor + " · last " + formatReplayLength(status.seconds)
}

function modeOptions() {
  return [
    { value: "monitor", label: "Monitor" },
    { value: "follow", label: "Follow active window" },
    { value: "pin", label: "Pin window" },
    { value: "region", label: "Region" }
  ]
}

function filterOptions() {
  return [
    { value: "all", label: "All" },
    { value: "allowlist", label: "Allowlist" },
    { value: "denylist", label: "Denylist" }
  ]
}

function hotkeyLuaSnippet() {
  return [
    'o.bind("SUPER + ALT + R", "Save replay", "omarchy-shell io.github.anthonyposchen.shadowplay save")',
    '-- o.bind("SUPER + ALT + S", "Start replay buffer", "omarchy-shell io.github.anthonyposchen.shadowplay start")',
    '-- o.bind("SUPER + ALT + X", "Stop replay buffer", "omarchy-shell io.github.anthonyposchen.shadowplay stop")',
    '-- o.bind("SUPER + ALT + T", "Toggle ShadowPlay panel", "omarchy-shell io.github.anthonyposchen.shadowplay toggle")',
    '-- o.bind("SUPER + ALT + O", "Open ShadowPlay", "omarchy-shell io.github.anthonyposchen.shadowplay open")',
    '-- o.bind("SUPER + ALT + C", "Close ShadowPlay", "omarchy-shell io.github.anthonyposchen.shadowplay close")'
  ].join("\n")
}

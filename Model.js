.pragma library

function boundedInteger(value, fallback, min, max) {
  var n = parseInt(value, 10)
  if (isNaN(n)) n = fallback
  if (n < min) return min
  if (n > max) return max
  return n
}

function capString(value, max) {
  var s = String(value == null ? "" : value)
  if (max > 0 && s.length > max) return s.slice(0, max)
  return s
}

function plainLabel(value, max) {
  var s = capString(value, max || 200)
  s = s.replace(/[<>&]/g, "")
  s = s.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
  return s
}

function parseJson(text, fallback) {
  try {
    return JSON.parse(String(text || ""))
  } catch (e) {
    return fallback
  }
}

function parseHelperObject(text) {
  var parsed = parseJson(text, null)
  if (parsed && typeof parsed === "object" && !Array.isArray(parsed))
    return parsed
  var s = String(text || "")
  var start = s.indexOf("{")
  var end = s.lastIndexOf("}")
  if (start < 0 || end <= start)
    return null
  parsed = parseJson(s.slice(start, end + 1), null)
  if (parsed && typeof parsed === "object" && !Array.isArray(parsed))
    return parsed
  return null
}

function parseStatus(text) {
  var status = parseJson(text, {})
  if (!status || typeof status !== "object") status = {}
  var encoder = status.encoder && typeof status.encoder === "object" ? status.encoder : {}
  return {
    running: status.running === true,
    monitor: capString(status.monitor || "", 64),
    configuredMonitor: capString(status.configuredMonitor || "", 64),
    seconds: boundedInteger(status.seconds, 60, minSeconds(), maxSeconds()),
    audio: normalizeAudio(status.audio),
    pid: capString(status.pid || "", 16),
    ipc: capString(status.ipc || "", 256),
    outputDir: capString(status.outputDir || "", 512),
    lastClip: capString(status.lastClip || "", 512),
    saving: boundedInteger(status.saving, 0, 0, 99),
    phase: status.running === true && !status.phase ? "live" : String(status.phase || ""),
    armed: status.armed === true || status.phase === "armed",
    linger: status.linger === true || status.phase === "linger",
    subject: capString(status.subject || "", 128),
    region: capString(status.region || "", 64),
    pinAddress: capString(status.pinAddress || "", 32),
    mode: normalizeMode(status.mode),
    filter: normalizeFilter(status.filter),
    captureExtent: normalizeCaptureExtent(status.captureExtent),
    clipResolution: normalizeClipResolution(status.clipResolution),
    clipScale: normalizeClipScale(status.clipScale),
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
      className: capString(klass, 128),
      initialClass: capString(row.initialClass || klass, 128),
      title: capString(row.title || "", 200),
      monitor: capString(row.monitor || "", 64),
      address: capString(row.address || "", 32),
      focused: row.focused === true
    })
    if (out.length >= 64) break
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
      name: capString(row.name, 64),
      size: capString(row.size || "", 32),
      focused: row.focused === true
    })
    if (out.length >= 16) break
  }
  return out
}

function normalizeAudio(value) {
  var audio = String(value || "desktop")
  if (audio === "none" || audio === "desktop" || audio === "both" || audio === "window" || audio === "window-mic") return audio
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

function normalizeClipResolution(value) {
  var res = String(value || "1080p")
  if (res === "720p" || res === "1080p" || res === "1440p" || res === "2160p") return res
  if (res === "1280x720") return "720p"
  if (res === "1920x1080") return "1080p"
  if (res === "2560x1440") return "1440p"
  if (res === "3840x2160" || res === "4k" || res === "4K") return "2160p"
  return "1080p"
}

function clipResolutionOptions() {
  return [
    { value: "720p", label: "720p · 1280×720" },
    { value: "1080p", label: "1080p · 1920×1080" },
    { value: "1440p", label: "1440p · 2560×1440" },
    { value: "2160p", label: "2160p · 3840×2160" }
  ]
}

function normalizeClipScale(value) {
  var scale = String(value || "fit")
  if (scale === "stretch" || scale === "distort" || scale === "fill" || scale === "cover" || scale === "crop") return "stretch"
  if (scale === "center" || scale === "native") return "center"
  return "fit"
}

function clipScaleOptions() {
  return [
    { value: "fit", label: "Scale to fit · bars" },
    { value: "stretch", label: "Stretch to fill · distort" },
    { value: "center", label: "Center native · 1:1" }
  ]
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
  var out = []
  function addToken(token) {
    var item = capString(String(token == null ? "" : token).trim(), 128)
    if (item) out.push(item)
  }
  function addText(text) {
    var chunks = String(text == null ? "" : text).split("\n")
    for (var i = 0; i < chunks.length; i++) {
      var bits = chunks[i].split(",")
      for (var j = 0; j < bits.length; j++) {
        addToken(bits[j])
        if (out.length >= 64) return
      }
    }
  }
  if (value === undefined || value === null || value === "") return out
  if (typeof value === "string") {
    addText(value)
    return out
  }
  if (value && typeof value === "object" && typeof value.length === "number") {
    if (value.length === 0) return out
    var asString = String(value)
    // QML often wraps a CSV as a 1-element list, or indexes a string by character.
    if (value.length === 1) {
      addText(value[0])
      return out
    }
    if (asString.length > 1 && value.length === asString.length && String(value[0]).length === 1)
      addText(asString)
    else {
      for (var k = 0; k < value.length && out.length < 64; k++) addText(value[k])
    }
    return out
  }
  addText(value)
  return out
}

function defaultBlacklist() {
  return ["org.quickshell", "waybar", "walker", "hyprlock"]
}

function encodeList(value) {
  return stringList(value).join(",")
}

function encodeLines(value) {
  return stringList(value).join("\n")
}

// Length and indexing stay in this file. QML `var` properties drop a JS
// array to its first element on first layout, which hid every class but
// one until Pick rebuilt the tree.
function listLength(value) {
  return stringList(value).length
}

function listItem(value, index) {
  var list = stringList(value)
  var i = parseInt(index, 10)
  if (isNaN(i) || i < 0 || i >= list.length) return ""
  return list[i]
}

function removeListItem(value, index) {
  return encodeList(replaceListItem(value, index, ""))
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

function audioOptions(mode) {
  var options = [
    { value: "none", label: "No audio" },
    { value: "desktop", label: "Desktop audio" },
    { value: "both", label: "Desktop + microphone" }
  ]
  if (mode === "follow" || mode === "pin") {
    options.push({ value: "window", label: "Window audio" })
    options.push({ value: "window-mic", label: "Window + microphone" })
  }
  return options
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

function savingLabel(count) {
  var n = boundedInteger(count, 0, 0, 99)
  if (n <= 0) return ""
  if (n === 1) return "Saving"
  return "Saving " + n
}

function modeStatusName(mode) {
  var options = modeOptions()
  var value = normalizeMode(mode)
  var i
  for (i = 0; i < options.length; i++) {
    if (options[i].value === value) return options[i].label
  }
  return "Monitor"
}

function sessionIsOn(status) {
  if (!status) return false
  return status.running === true || status.phase === "armed" || status.phase === "linger" || status.armed === true || status.linger === true
}

function statusHeadline(status, mode) {
  if (!sessionIsOn(status)) return "Disabled"
  return modeStatusName(mode || (status && status.mode))
}

function statusDetail(status) {
  if (!status) return ""
  var saving = savingLabel(status.saving)
  if (saving) return saving
  if (!sessionIsOn(status)) return ""
  if (status.phase === "armed" || status.armed === true) return "Armed"
  return "recording last " + formatReplayLength(status.seconds)
}

function statusLabel(status, mode) {
  var head = statusHeadline(status, mode)
  var detail = statusDetail(status)
  if (!detail || detail === head) return head
  return head + " · " + detail
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

function hotkeyBindSnippet() {
  var id = "io.github.anthonyposchen.instant-replay"
  return [
    'bindd = SUPER ALT, R, Save replay, exec, omarchy-shell ' + id + ' save',
    '# bindd = SUPER ALT, S, Start replay buffer, exec, omarchy-shell ' + id + ' start',
    '# bindd = SUPER ALT, X, Stop replay buffer, exec, omarchy-shell ' + id + ' stop',
    '# bindd = SUPER ALT, T, Toggle Instant Replay panel, exec, omarchy-shell ' + id + ' toggle',
    '# bindd = SUPER ALT, O, Open Instant Replay, exec, omarchy-shell ' + id + ' open',
    '# bindd = SUPER ALT, C, Close Instant Replay, exec, omarchy-shell ' + id + ' close'
  ].join("\n")
}

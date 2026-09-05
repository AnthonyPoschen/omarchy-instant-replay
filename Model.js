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
  return {
    running: status.running === true,
    monitor: String(status.monitor || ""),
    configuredMonitor: String(status.configuredMonitor || ""),
    seconds: boundedInteger(status.seconds, 60, 15, 600),
    audio: normalizeAudio(status.audio),
    pid: String(status.pid || ""),
    ipc: String(status.ipc || ""),
    outputDir: String(status.outputDir || ""),
    lastClip: String(status.lastClip || "")
  }
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

function secondsOptions() {
  return [
    { value: "15", label: "15 seconds" },
    { value: "30", label: "30 seconds" },
    { value: "60", label: "1 minute" },
    { value: "120", label: "2 minutes" },
    { value: "300", label: "5 minutes" },
    { value: "600", label: "10 minutes" }
  ]
}

function audioOptions() {
  return [
    { value: "none", label: "No audio" },
    { value: "desktop", label: "Desktop audio" },
    { value: "both", label: "Desktop + microphone" }
  ]
}

function statusLabel(status) {
  if (!status || status.running !== true) return "Buffer off"
  var monitor = status.monitor || "monitor"
  return monitor + " · last " + status.seconds + "s"
}

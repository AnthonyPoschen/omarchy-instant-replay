import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.anthonyposchen.shadowplay"
  ipcTarget: "io.github.anthonyposchen.shadowplay"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string helperPath: ""
  property var status: ({ running: false, monitor: "", seconds: 60, audio: "desktop", lastClip: "" })
  property var monitors: []
  property bool busy: false
  property bool autostartAttempted: false
  property string lastError: ""
  property string focusSection: "toggle"
  property bool cursorActive: false

  readonly property var barIdentity: hostWidget || root
  readonly property bool running: status.running === true
  readonly property string configuredMonitor: String(setting("monitor", "") || "")
  readonly property int configuredSeconds: Model.boundedInteger(setting("seconds", 60), 60, 15, 600)
  readonly property string configuredAudio: Model.normalizeAudio(setting("audio", "desktop"))
  readonly property bool configuredAutostart: setting("autostart", false) === true || String(setting("autostart", false)) === "true"
  readonly property color contentForeground: root.bar ? root.bar.foreground : Color.foreground
  readonly property string contentFontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property var monitorChoices: Model.monitorOptions(monitors)
  readonly property var secondsChoices: Model.secondsOptions()
  readonly property var audioChoices: Model.audioOptions()

  function open() {
    root.refresh()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function runHelper(args) {
    var command = ["bash", root.helperPath]
    for (var i = 0; i < args.length; i++) command.push(args[i])
    return command
  }

  function refresh() {
    if (root.helperPath === "") return
    if (!monitorsProc.running) {
      monitorsProc.command = root.runHelper(["monitors", "--json"])
      monitorsProc.running = true
    }
    if (statusProc.running) return
    statusProc.command = root.runHelper(["status", "--json"])
    statusProc.running = true
  }

  function startBuffer() {
    if (root.helperPath === "" || actionProc.running) return
    root.busy = true
    root.lastError = ""
    actionProc.command = root.runHelper([
      "start",
      "--monitor=" + root.configuredMonitor,
      "--seconds=" + String(root.configuredSeconds),
      "--audio=" + root.configuredAudio
    ])
    actionProc.running = true
  }

  function stopBuffer() {
    if (root.helperPath === "" || actionProc.running) return
    root.busy = true
    root.lastError = ""
    actionProc.command = root.runHelper(["stop"])
    actionProc.running = true
  }

  function save() {
    if (root.helperPath === "" || actionProc.running) return
    if (!root.running) {
      root.open()
      return
    }
    root.busy = true
    root.lastError = ""
    actionProc.command = root.runHelper(["save"])
    actionProc.running = true
  }

  function maybeAutostart() {
    if (root.autostartAttempted || root.helperPath === "") return
    root.autostartAttempted = true
    if (root.configuredAutostart && root.running === false) root.startBuffer()
  }

  onHelperPathChanged: root.refresh()
  onConfiguredAutostartChanged: {
    if (root.configuredAutostart) root.maybeAutostart()
  }
  Component.onCompleted: root.refresh()

  Timer {
    id: statusTimer
    interval: 2000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    stderr: StdioCollector { id: statusError; waitForEnd: true }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        if (exitCode === 0) {
          root.status = Model.parseStatus(statusOutput.text)
          root.maybeAutostart()
        } else if (root.lastError === "") {
          var message = String(statusError.text || "").trim()
          if (message !== "") root.lastError = message
        }
      })
    }
  }

  Process {
    id: monitorsProc
    stdout: StdioCollector { id: monitorsOutput; waitForEnd: true }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        if (exitCode === 0) root.monitors = Model.parseMonitors(monitorsOutput.text)
      })
    }
  }

  Process {
    id: actionProc
    stdout: StdioCollector { id: actionOutput; waitForEnd: true }
    stderr: StdioCollector { id: actionError; waitForEnd: true }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        root.busy = false
        if (exitCode !== 0) {
          var message = String(actionError.text || "").trim()
          root.lastError = message !== "" ? message : "ShadowPlay command failed."
        } else {
          root.lastError = ""
        }
        root.refresh()
      })
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(body.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: monitorDropdown.popupOpen || secondsDropdown.popupOpen || audioDropdown.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        PanelHero {
          title: "ShadowPlay"
          meta: Model.statusLabel(root.status)
          detail: root.lastError !== "" ? root.lastError : (root.status.lastClip !== "" ? root.status.lastClip : "Save the last seconds of the selected monitor.")
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          trailingControl: Component {
            ToggleSwitch {
              checked: root.running
              busy: root.busy
              foreground: root.contentForeground
              onToggled: root.running ? root.stopBuffer() : root.startBuffer()
            }
          }
        }

        PanelSeparator {}

        Toggle {
          width: parent.width
          label: "Start with the bar"
          description: "Begin buffering when Omarchy shell loads this widget."
          checked: root.configuredAutostart
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.persistSettings({ autostart: !root.configuredAutostart })
        }

        Dropdown {
          id: monitorDropdown
          width: parent.width
          label: "Monitor"
          value: root.configuredMonitor
          options: root.monitorChoices
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onChanged: function(value) { root.persistSettings({ monitor: value }) }
        }

        Dropdown {
          id: secondsDropdown
          width: parent.width
          label: "Replay length"
          value: String(root.configuredSeconds)
          options: root.secondsChoices
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onChanged: function(value) { root.persistSettings({ seconds: Model.boundedInteger(value, 60, 15, 600) }) }
        }

        Dropdown {
          id: audioDropdown
          width: parent.width
          label: "Audio"
          value: root.configuredAudio
          options: root.audioChoices
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onChanged: function(value) { root.persistSettings({ audio: Model.normalizeAudio(value) }) }
        }

        Button {
          width: parent.width
          text: root.running ? "Save replay" : "Start buffer"
          enabled: !root.busy
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.running ? root.save() : root.startBuffer()
        }
      }
    }
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.anthonyposchen.instant-replay"
  ipcTarget: "io.github.anthonyposchen.instant-replay"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property string helperPath: ""
  property var status: ({ running: false, monitor: "", seconds: 60, audio: "desktop", lastClip: "", saving: 0, phase: "off", armed: false, linger: false, subject: "" })
  property var monitors: []
  property bool busy: false
  property bool resumeAttempted: false
  property string lastError: ""
  property string focusSection: "toggle"
  property bool cursorActive: false
  property bool extrasEncoderOpen: false
  property string hotkeyCopyStatus: ""
  property string clipCopyStatus: ""

  readonly property var barIdentity: hostWidget || root
  readonly property bool running: status.running === true
  readonly property int savingCount: Model.boundedInteger(status.saving, 0, 0, 99)
  readonly property bool armed: status.armed === true || status.phase === "armed"
  readonly property bool sessionOn: running || armed || status.phase === "linger" || status.linger === true
  readonly property string configuredMonitor: String(setting("monitor", "") || "")
  readonly property int configuredSeconds: Model.boundedInteger(setting("seconds", 60), 60, Model.minSeconds(), Model.maxSeconds())
  readonly property string configuredAudio: {
    var audio = Model.normalizeAudio(setting("audio", "desktop"))
    if ((audio === "window" || audio === "window-mic") && root.configuredMode !== "follow" && root.configuredMode !== "pin")
      return audio === "window-mic" ? "both" : "desktop"
    return audio
  }
  readonly property string configuredOutputDir: String(setting("outputDir", "") || "")
  readonly property string configuredMode: Model.normalizeMode(setting("mode", "monitor"))
  readonly property string configuredRegion: String(setting("region", "") || "")
  readonly property string configuredPinAddress: String(setting("pinAddress", "") || "")
  readonly property color contentForeground: root.bar ? root.bar.foreground : Color.foreground
  readonly property string contentFontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property var modeChoices: Model.modeOptions()
  readonly property var monitorChoices: Model.monitorOptions(monitors)
  readonly property var secondsChoices: Model.secondsOptions()
  readonly property var audioChoices: Model.audioOptions(root.configuredMode)
  readonly property var filterChoices: Model.filterOptions()
  readonly property string configuredFilter: Model.normalizeFilter(setting("filter", "all"))
  readonly property var configuredMatchList: {
    var stored = setting("matchList", undefined)
    if (stored !== undefined && stored !== null)
      return Model.stringList(stored)
    if (root.status && root.status.matchList !== undefined && root.status.matchList !== null)
      return Model.stringList(root.status.matchList)
    return []
  }
  readonly property var clipResolutionChoices: Model.clipResolutionOptions()
  readonly property string configuredClipResolution: Model.normalizeClipResolution(setting("clipResolution", "1080p"))
  readonly property var clipScaleChoices: Model.clipScaleOptions()
  readonly property string configuredClipScale: Model.normalizeClipScale(setting("clipScale", "fit"))
  readonly property string configuredCodec: Model.normalizeCodec(setting("codec", "auto"))
  readonly property int configuredFps: Model.boundedInteger(setting("fps", 60), 60, Model.minFps(), Model.maxFps())
  readonly property int configuredQuality: Model.boundedInteger(setting("quality", 40000), 40000, Model.minQuality(), Model.maxQuality())
  readonly property bool configuredCursor: setting("cursor", true) !== false && String(setting("cursor", true)) !== "false"
  readonly property string configuredFramerateMode: Model.normalizeFramerateMode(setting("framerateMode", "cfr"))
  readonly property string configuredBitrateMode: Model.normalizeBitrateMode(setting("bitrateMode", "cbr"))
  readonly property var codecChoices: Model.codecOptions()
  readonly property var fpsChoices: Model.fpsOptions()
  readonly property var qualityChoices: Model.qualityOptions()
  readonly property var framerateModeChoices: Model.framerateModeOptions()
  readonly property var bitrateModeChoices: Model.bitrateModeOptions()
  readonly property var configuredBlacklist: {
    var stored = setting("blacklist", undefined)
    if (stored !== undefined && stored !== null)
      return Model.stringList(stored)
    if (root.status && root.status.blacklist !== undefined && root.status.blacklist !== null)
      return Model.stringList(root.status.blacklist)
    return Model.defaultBlacklist()
  }

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

  function applySetting(key, value) {
    var values = {}
    values[key] = value
    root.persistSettings(values)
    if (root.helperPath === "" || actionProc.running) return
    root.busy = true
    root.lastError = ""
    actionProc.command = root.runHelper(["settings", "set", key, String(value)])
    actionProc.running = true
  }

  function applyMatchList(list) {
    var encoded = Model.encodeList(list)
    root.persistSettings({ matchList: encoded })
    if (root.helperPath === "" || actionProc.running) return
    root.busy = true
    root.lastError = ""
    actionProc.command = root.runHelper(["settings", "set", "matchList", encoded])
    actionProc.running = true
  }

  function applyBlacklist(list) {
    var encoded = Model.encodeList(list)
    root.persistSettings({ blacklist: encoded })
    if (root.helperPath === "" || actionProc.running) return
    root.busy = true
    root.lastError = ""
    actionProc.command = root.runHelper(["settings", "set", "blacklist", encoded])
    actionProc.running = true
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
    var args = [
      "start",
      "--mode=" + root.configuredMode,
      "--seconds=" + String(root.configuredSeconds),
      "--audio=" + root.configuredAudio
    ]
    if (root.configuredMode !== "follow" && root.configuredMode !== "pin") args.push("--monitor=" + root.configuredMonitor)
    if (root.configuredMode === "region") args.push("--region=" + root.configuredRegion)
    if (root.configuredMode === "pin") args.push("--pin=" + root.configuredPinAddress)
    actionProc.command = root.runHelper(args)
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
    if (root.helperPath === "") return
    if (!root.running) return
    root.lastError = ""
    Quickshell.execDetached(root.runHelper(["save"]))
    Qt.callLater(root.refresh)
  }

  function copyHotkeys() {
    var text = Model.hotkeyBindSnippet()
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
    root.hotkeyCopyStatus = "Copied"
  }

  function copyLastClip() {
    var text = String(root.status.lastClip || "")
    if (text === "") return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
    root.clipCopyStatus = "Copied"
  }

  function pickWindow() {
    if (root.helperPath === "" || actionProc.running) return
    root.close()
    Qt.callLater(function() {
      if (actionProc.running) return
      root.busy = true
      root.lastError = ""
      actionProc.command = root.runHelper(["pick-window"])
      actionProc.running = true
    })
  }

  function pickMatchWindow() {
    if (root.helperPath === "" || actionProc.running) return
    root.close()
    Qt.callLater(function() {
      if (actionProc.running) return
      root.busy = true
      root.lastError = ""
      actionProc.command = root.runHelper(["pick-match-window"])
      actionProc.running = true
    })
  }

  function pickBlacklistWindow() {
    if (root.helperPath === "" || actionProc.running) return
    root.close()
    Qt.callLater(function() {
      if (actionProc.running) return
      root.busy = true
      root.lastError = ""
      actionProc.command = root.runHelper(["pick-blacklist-window"])
      actionProc.running = true
    })
  }

  function pickRegion() {
    if (root.helperPath === "" || actionProc.running) return
    root.close()
    Qt.callLater(function() {
      if (actionProc.running) return
      root.busy = true
      root.lastError = ""
      actionProc.command = root.runHelper(["pick-region"])
      actionProc.running = true
    })
  }

  function pickOutputDir() {
    if (folderPickProc.running) return
    root.close()
    Qt.callLater(function() {
      if (folderPickProc.running) return
      folderPickProc.command = ["omarchy-file-select", "--directory", "--title", "Clips folder"]
      folderPickProc.running = true
    })
  }

  function maybeResumeSession() {
    if (root.resumeAttempted || root.helperPath === "") return
    root.resumeAttempted = true
    if (root.running) return
    var phase = String(root.status.phase || "")
    if (phase === "live" || phase === "armed" || phase === "linger")
      root.startBuffer()
  }

  onHelperPathChanged: root.refresh()
  Component.onCompleted: root.refresh()

  Timer {
    id: statusTimer
    interval: root.savingCount > 0 ? 400 : 2000
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Timer {
    id: followTimer
    interval: 400
    repeat: true
    running: (root.configuredMode === "follow" || root.configuredMode === "pin") && root.sessionOn && root.helperPath !== ""
    onTriggered: {
      if (followTickProc.running) return
      followTickProc.command = root.runHelper(["tick"])
      followTickProc.running = true
    }
  }

  Process {
    id: followTickProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
  }

  Process {
    id: statusProc
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    stderr: StdioCollector { id: statusError; waitForEnd: true }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        if (exitCode === 0) {
          root.status = Model.parseStatus(statusOutput.text)
          root.maybeResumeSession()
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
    id: folderPickProc
    stdout: StdioCollector { id: folderPickOut; waitForEnd: true }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        if (exitCode === 0) {
          var path = String(folderPickOut.text || "").trim()
          if (path !== "") {
            outputDirField.text = path
            root.applySetting("outputDir", path)
          }
        }
        root.open()
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
          root.lastError = message !== "" ? message : "Instant Replay command failed."
        } else {
          root.lastError = ""
          var parsed = Model.parseJson(actionOutput.text, null)
          if (parsed && typeof parsed === "object" && (parsed.region !== undefined || parsed.pinAddress !== undefined || parsed.blacklist !== undefined || parsed.matchList !== undefined)) {
            var values = {}
            if (parsed.region !== undefined) values.region = String(parsed.region || "")
            if (parsed.pinAddress !== undefined) values.pinAddress = String(parsed.pinAddress || "")
            if (parsed.blacklist !== undefined) values.blacklist = Model.encodeList(parsed.blacklist)
            if (parsed.matchList !== undefined) values.matchList = Model.encodeList(parsed.matchList)
            if (parsed.mode) values.mode = Model.normalizeMode(parsed.mode)
            root.persistSettings(values)
          }
        }
        root.refresh()
        var lastArg = String(actionProc.command && actionProc.command.length ? actionProc.command[actionProc.command.length - 1] : "")
        if (lastArg === "pick-region" || lastArg === "pick-window" || lastArg === "pick-blacklist-window" || lastArg === "pick-match-window")
          root.open()
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
      blocked: monitorDropdown.popupOpen || secondsDropdown.popupOpen || audioDropdown.popupOpen || modeDropdown.popupOpen || filterDropdown.popupOpen || clipResolutionDropdown.popupOpen || clipScaleDropdown.popupOpen || codecDropdown.popupOpen || fpsDropdown.popupOpen || qualityDropdown.popupOpen || framerateDropdown.popupOpen || bitrateDropdown.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        PanelHero {
          title: "Instant Replay"
          meta: Model.statusLabel(root.status)
          detail: ""
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
        }

        Text {
          width: parent.width
          visible: root.lastError !== ""
          text: root.lastError
          wrapMode: Text.Wrap
          color: Color.urgent
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        Toggle {
          width: parent.width
          label: "Replay buffer"
          description: root.running ? "Live. Left-click the bar icon to save." : (root.armed ? "Armed. Waiting for a window." : "Off. Nothing is being captured.")
          checked: root.sessionOn
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: {
            if (root.busy) return
            root.sessionOn ? root.stopBuffer() : root.startBuffer()
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)
          visible: String(root.status.lastClip || "") !== ""

          Text {
            width: parent.width - copyClipButton.width - parent.spacing
            text: root.status.lastClip
            elide: Text.ElideMiddle
            color: Qt.darker(root.contentForeground, 1.3)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            verticalAlignment: Text.AlignVCenter
            height: copyClipButton.height
          }

          Button {
            id: copyClipButton
            text: root.clipCopyStatus !== "" ? root.clipCopyStatus : "Copy"
            enabled: !root.busy
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.copyLastClip()
          }
        }

        PanelSeparator {}

        Dropdown {
          id: modeDropdown
          width: parent.width
          label: "Mode"
          value: root.configuredMode
          options: root.modeChoices
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onChanged: function(value) { root.applySetting("mode", Model.normalizeMode(value)) }
        }

        Dropdown {
          id: filterDropdown
          width: parent.width
          visible: root.configuredMode === "follow"
          label: "Filter"
          value: root.configuredFilter
          options: root.filterChoices
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onChanged: function(value) { root.applySetting("filter", Model.normalizeFilter(value)) }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.configuredMode === "follow" && root.configuredFilter === "allowlist"
          height: visible ? implicitHeight : 0

          Text {
            text: "Allowlist"
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Repeater {
            model: root.configuredMatchList
            delegate: Row {
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width - 36 - parent.spacing
                text: modelData
                elide: Text.ElideMiddle
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                verticalAlignment: Text.AlignVCenter
                height: 36
              }

              Button {
                width: 36
                text: "×"
                enabled: !root.busy
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.applyMatchList(Model.replaceListItem(root.configuredMatchList, index, ""))
              }
            }
          }

          Button {
            width: parent.width
            text: "Pick window"
            enabled: !root.busy
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.pickMatchWindow()
          }

          Button {
            width: parent.width
            text: "Empty allowlist"
            enabled: !root.busy && root.configuredMatchList.length > 0
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.applyMatchList([])
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(6)
          visible: root.configuredMode === "follow" && root.configuredFilter === "denylist"
          height: visible ? implicitHeight : 0

          Text {
            text: "Blacklist"
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          Repeater {
            model: root.configuredBlacklist
            delegate: Row {
              width: parent.width
              spacing: Style.space(6)

              Text {
                width: parent.width - 36 - parent.spacing
                text: modelData
                elide: Text.ElideMiddle
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                verticalAlignment: Text.AlignVCenter
                height: 36
              }

              Button {
                width: 36
                text: "×"
                enabled: !root.busy
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.applyBlacklist(Model.replaceListItem(root.configuredBlacklist, index, ""))
              }
            }
          }

          Button {
            width: parent.width
            text: "Pick window"
            enabled: !root.busy
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.pickBlacklistWindow()
          }

          Button {
            width: parent.width
            text: "Empty blacklist"
            enabled: !root.busy && root.configuredBlacklist.length > 0
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.applyBlacklist([])
          }
        }

        Dropdown {
          id: monitorDropdown
          width: parent.width
          visible: root.configuredMode === "monitor"
          label: "Monitor"
          value: root.configuredMonitor
          options: root.monitorChoices
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onChanged: function(value) { root.applySetting("monitor", value) }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)
          visible: root.configuredMode === "pin"
          height: visible ? implicitHeight : 0

          Text {
            width: parent.width - pickWindowButton.width - parent.spacing
            text: String(root.status.subject || "") !== "" ? ("Pinned · " + root.status.subject) : (root.configuredPinAddress !== "" ? ("Pinned · " + root.configuredPinAddress) : "No window yet")
            elide: Text.ElideMiddle
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            verticalAlignment: Text.AlignVCenter
            height: pickWindowButton.height
          }

          Button {
            id: pickWindowButton
            text: "Pick window"
            enabled: !root.busy
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.pickWindow()
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)
          visible: root.configuredMode === "region"
          height: visible ? implicitHeight : 0

          Text {
            width: parent.width - pickRegionButton.width - parent.spacing
            text: root.configuredRegion !== "" ? root.configuredRegion : "No rectangle yet"
            elide: Text.ElideMiddle
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            verticalAlignment: Text.AlignVCenter
            height: pickRegionButton.height
          }

          Button {
            id: pickRegionButton
            text: "Pick region"
            enabled: !root.busy
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.pickRegion()
          }
        }

        Dropdown {
          id: secondsDropdown
          width: parent.width
          label: "Replay Window"
          value: String(root.configuredSeconds)
          options: root.secondsChoices
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onChanged: function(value) { root.applySetting("seconds", Model.boundedInteger(value, 60, Model.minSeconds(), Model.maxSeconds())) }
        }

        Dropdown {
          id: audioDropdown
          width: parent.width
          label: "Audio"
          value: root.configuredAudio
          options: root.audioChoices
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onChanged: function(value) { root.applySetting("audio", Model.normalizeAudio(value)) }
        }

        Dropdown {
          id: clipResolutionDropdown
          width: parent.width
          label: "Clip resolution"
          value: root.configuredClipResolution
          options: root.clipResolutionChoices
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onChanged: function(value) { root.applySetting("clipResolution", Model.normalizeClipResolution(value)) }
        }

        Dropdown {
          id: clipScaleDropdown
          width: parent.width
          label: "Clip layout"
          value: root.configuredClipScale
          options: root.clipScaleChoices
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onChanged: function(value) { root.applySetting("clipScale", Model.normalizeClipScale(value)) }
        }

        Text {
          text: "Clips folder"
          color: Qt.darker(root.contentForeground, 1.4)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          TextField {
            id: outputDirField
            width: parent.width - browseFolderButton.width - parent.spacing
            text: root.configuredOutputDir
            placeholderText: root.status.outputDir !== "" ? root.status.outputDir : "Videos/Replays"
            foreground: root.contentForeground
            onEditingFinished: {
              if (root.configuredOutputDir === text) return
              root.applySetting("outputDir", text)
            }
          }

          Button {
            id: browseFolderButton
            text: "Browse"
            enabled: !folderPickProc.running
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.pickOutputDir()
          }
        }

        Button {
          width: parent.width
          text: root.running ? "Save replay" : (root.armed ? "Armed" : "Start buffer")
          enabled: !root.busy && !(root.armed && !root.running)
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.running ? root.save() : root.startBuffer()
        }

        PanelSeparator {}

        ExtraGroup {
          title: "Encoder"
          open: root.extrasEncoderOpen
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onToggled: root.extrasEncoderOpen = !root.extrasEncoderOpen

          Dropdown {
            id: codecDropdown
            width: parent.width
            label: "Codec"
            value: root.configuredCodec
            options: root.codecChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("codec", Model.normalizeCodec(value)) }
          }

          Dropdown {
            id: fpsDropdown
            width: parent.width
            label: "FPS"
            value: String(root.configuredFps)
            options: root.fpsChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("fps", Model.boundedInteger(value, 60, Model.minFps(), Model.maxFps())) }
          }

          Dropdown {
            id: qualityDropdown
            width: parent.width
            label: "Quality"
            value: String(root.configuredQuality)
            options: root.qualityChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("quality", Model.boundedInteger(value, 40000, Model.minQuality(), Model.maxQuality())) }
          }

          Dropdown {
            id: framerateDropdown
            width: parent.width
            label: "Framerate mode"
            value: root.configuredFramerateMode
            options: root.framerateModeChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("framerateMode", Model.normalizeFramerateMode(value)) }
          }

          Dropdown {
            id: bitrateDropdown
            width: parent.width
            label: "Bitrate mode"
            value: root.configuredBitrateMode
            options: root.bitrateModeChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("bitrateMode", Model.normalizeBitrateMode(value)) }
          }

          Toggle {
            width: parent.width
            label: "Cursor"
            description: "Include the pointer in the Replay Buffer."
            checked: root.configuredCursor
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.applySetting("cursor", !root.configuredCursor)
          }
        }

        Button {
          width: parent.width
          text: root.hotkeyCopyStatus !== "" ? root.hotkeyCopyStatus : "Copy keybinds"
          enabled: !root.busy
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.copyHotkeys()
        }
      }
    }
  }

  component ExtraGroup: Column {
    id: extra
    width: parent ? parent.width : implicitWidth
    spacing: Style.space(6)

    property string title: ""
    property bool open: false
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    default property alias extraContent: extraBody.data
    signal toggled()

    MouseArea {
      width: parent.width
      height: extraHeader.implicitHeight
      cursorShape: Qt.PointingHandCursor
      onClicked: extra.toggled()

      Row {
        id: extraHeader
        width: parent.width
        spacing: Style.space(10)

        Text {
          text: extra.open ? "▼" : "▶"
          color: extra.foreground
          font.family: extra.fontFamily
          font.pixelSize: Style.font.heading
          font.bold: true
        }

        PanelSectionHeader {
          text: extra.title + (extra.open ? "  ·  Hide" : "  ·  Show")
          foreground: extra.foreground
          fontFamily: extra.fontFamily
          fontSize: Style.font.body
        }
      }
    }

    Column {
      id: extraBody
      width: parent.width
      spacing: Style.space(8)
      visible: extra.open
      height: extra.open ? implicitHeight : 0
    }
  }
}

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
  property var status: ({ running: false, monitor: "", seconds: 60, audio: "desktop", lastClip: "", saving: 0, phase: "off", linger: false, subject: "" })
  property var monitors: []
  property bool busy: false
  property bool resumeAttempted: false
  property string lastError: ""
  property string focusSection: "toggle"
  property bool cursorActive: false
  property bool extrasEncoderOpen: false
  property bool extrasModeOpen: false
  property bool extrasConfigOpen: false
  property string hotkeyCopyStatus: ""
  property var commandQueue: []
  property string pendingAfter: ""
  property bool pickShouldReopen: false
  property string statusOut: ""
  property string statusErr: ""
  property string monitorsOut: ""
  property string actionOut: ""
  property string actionErr: ""
  property string folderOut: ""
  readonly property int helperOutputLimit: 262144

  readonly property var barIdentity: hostWidget || root
  readonly property bool running: status.running === true
  readonly property int savingCount: Model.boundedInteger(status.saving, 0, 0, 99)
  readonly property bool sessionOn: running
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
    var stored = root.settings ? root.settings.matchList : undefined
    if (stored !== undefined && stored !== null)
      return stored
    if (root.status && root.status.matchList !== undefined && root.status.matchList !== null)
      return root.status.matchList
    return ""
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
    var stored = root.settings ? root.settings.blacklist : undefined
    if (stored !== undefined && stored !== null)
      return stored
    if (root.status && root.status.blacklist !== undefined && root.status.blacklist !== null)
      return root.status.blacklist
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

  function ingest(proc, which, chunk) {
    var cur = root[which] || ""
    var next = String(chunk || "")
    if (cur.length + next.length > root.helperOutputLimit) {
      if (proc && typeof proc.signal === "function") proc.signal(15)
      root[which] = ""
      return
    }
    root[which] = cur + next
  }

  function runQueuedCommand(args, after) {
    root.busy = true
    root.lastError = ""
    root.actionOut = ""
    root.actionErr = ""
    root.pendingAfter = after || ""
    actionProc.command = root.runHelper(args)
    actionProc.running = true
  }

  function enqueueCommand(args, after) {
    if (root.helperPath === "") return
    if (actionProc.running) {
      root.commandQueue.push({ args: args, after: after || "" })
      return
    }
    root.runQueuedCommand(args, after)
  }

  function applySetting(key, value) {
    var values = {}
    values[key] = value
    root.persistSettings(values)
    root.enqueueCommand(["settings", "set", key, String(value)])
  }

  function applyMatchList(list) {
    var encoded = Model.encodeList(list)
    root.persistSettings({ matchList: encoded })
    root.enqueueCommand(["settings", "set", "matchList", encoded])
  }

  function applyBlacklist(list) {
    var encoded = Model.encodeList(list)
    root.persistSettings({ blacklist: encoded })
    root.enqueueCommand(["settings", "set", "blacklist", encoded])
  }

  function runHelper(args) {
    var command = ["/usr/bin/bash", root.helperPath]
    for (var i = 0; i < args.length; i++) command.push(args[i])
    return command
  }

  function refresh() {
    if (root.helperPath === "") return
    if (!monitorsProc.running) {
      root.monitorsOut = ""
      monitorsProc.command = root.runHelper(["monitors", "--json"])
      monitorsProc.running = true
    }
    if (statusProc.running) return
    root.statusOut = ""
    root.statusErr = ""
    statusProc.command = root.runHelper(["status", "--json"])
    statusProc.running = true
  }

  function startBuffer() {
    var args = [
      "start",
      "--mode=" + root.configuredMode,
      "--seconds=" + String(root.configuredSeconds),
      "--audio=" + root.configuredAudio
    ]
    if (root.configuredMode !== "follow" && root.configuredMode !== "pin") args.push("--monitor=" + root.configuredMonitor)
    if (root.configuredMode === "region") args.push("--region=" + root.configuredRegion)
    if (root.configuredMode === "pin") args.push("--pin=" + root.configuredPinAddress)
    root.enqueueCommand(args)
  }

  function stopBuffer() {
    root.enqueueCommand(["stop"])
  }

  function save() {
    if (root.helperPath === "") return
    if (!root.running) return
    root.lastError = ""
    Quickshell.execDetached(root.runHelper(["save"]))
    Qt.callLater(root.refresh)
  }

  function copyHotkeys() {
    Quickshell.execDetached(["/usr/bin/wl-copy", "--", Model.hotkeyBindSnippet()])
    root.hotkeyCopyStatus = "Copied"
  }

  function lastClipPath() {
    var path = String(root.status.lastClip || "")
    if (path.charAt(0) !== "/" || path.indexOf("\n") !== -1) return ""
    return path
  }

  function lastClipFolder() {
    var path = root.lastClipPath()
    var slash
    if (path === "") return ""
    slash = path.lastIndexOf("/")
    if (slash < 1) return ""
    return path.slice(0, slash)
  }

  function openLastClipInOmacut() {
    var path = root.lastClipPath()
    if (path === "") return
    // omacut takes args.at(1) as the video. It does not skip "--".
    Quickshell.execDetached(["/usr/bin/omacut", path])
  }

  function clipsFolderPath() {
    var dir = String(root.configuredOutputDir || "")
    if (dir.charAt(0) === "/" && dir.indexOf("\n") === -1) return dir
    dir = String(root.status.outputDir || "")
    if (dir.charAt(0) === "/" && dir.indexOf("\n") === -1) return dir
    return root.lastClipFolder()
  }

  function openClipsFolder() {
    var dir = root.clipsFolderPath()
    if (dir === "") return
    Quickshell.execDetached(["/usr/bin/xdg-open", "--", dir])
  }

  function beginPick(args) {
    root.pickShouldReopen = true
    root.close()
    Qt.callLater(function() {
      if (root.helperPath === "") {
        root.pickShouldReopen = false
        root.open()
        return
      }
      root.enqueueCommand(args, "pick")
    })
  }

  function finishPickReopen() {
    if (!root.pickShouldReopen) return
    root.pickShouldReopen = false
    root.open()
  }

  function pickWindow() {
    root.beginPick(["pick-window"])
  }

  function pickMatchWindow() {
    root.beginPick(["pick-match-window"])
  }

  function pickBlacklistWindow() {
    root.beginPick(["pick-blacklist-window"])
  }

  function pickRegion() {
    root.beginPick(["pick-region"])
  }

  function pickOutputDir() {
    if (folderPickProc.running) return
    root.close()
    Qt.callLater(function() {
      if (folderPickProc.running) return
      root.folderOut = ""
      folderPickProc.command = ["omarchy-file-select", "--directory", "--title", "Output folder"]
      folderPickProc.running = true
    })
  }

  function maybeResumeSession() {
    if (root.resumeAttempted || root.helperPath === "") return
    root.resumeAttempted = true
    if (root.running) return
    var phase = String(root.status.phase || "")
    if (phase === "off") return
    if (phase === "live" || phase === "linger" || phase === "armed" || phase === "")
      root.startBuffer()
  }

  onHelperPathChanged: root.refresh()
  Component.onCompleted: root.refresh()
  Component.onDestruction: {
    statusProc.running = false
    monitorsProc.running = false
    actionProc.running = false
    folderPickProc.running = false
  }

  Timer {
    id: statusTimer
    interval: {
      if (root.savingCount > 0) return 400
      if ((root.configuredMode === "follow" || root.configuredMode === "pin") && root.sessionOn) return 400
      if (root.running || root.opened) return 2000
      return 8000
    }
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.ingest(statusProc, "statusOut", chunk) }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.ingest(statusProc, "statusErr", chunk) }
    }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        if (exitCode === 0) {
          root.status = Model.parseStatus(root.statusOut)
          root.maybeResumeSession()
        } else if (root.lastError === "") {
          var message = Model.plainLabel(String(root.statusErr || "").trim(), 400)
          if (message !== "") root.lastError = message
        }
      })
    }
  }

  Process {
    id: monitorsProc
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.ingest(monitorsProc, "monitorsOut", chunk) }
    }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        if (exitCode === 0) root.monitors = Model.parseMonitors(root.monitorsOut)
      })
    }
  }

  Process {
    id: folderPickProc
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.ingest(folderPickProc, "folderOut", chunk) }
    }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        if (exitCode === 0) {
          var path = String(root.folderOut || "").trim()
          if (path !== "" && path.charAt(0) === "/" && path.indexOf("\n") === -1) {
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
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.ingest(actionProc, "actionOut", chunk) }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(chunk) { root.ingest(actionProc, "actionErr", chunk) }
    }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        var reopen = root.pendingAfter === "pick"
        root.pendingAfter = ""
        if (exitCode !== 0) {
          var message = Model.plainLabel(String(root.actionErr || "").trim(), 400)
          root.lastError = message !== "" ? message : "Instant Replay command failed."
        } else {
          root.lastError = ""
          var parsed = Model.parseHelperObject(root.actionOut)
          if (parsed && typeof parsed === "object") {
            var values = {}
            if (parsed.region !== undefined) values.region = String(parsed.region || "")
            if (parsed.pinAddress !== undefined) values.pinAddress = String(parsed.pinAddress || "")
            if (parsed.blacklist !== undefined) values.blacklist = Model.encodeList(parsed.blacklist)
            if (parsed.matchList !== undefined) values.matchList = Model.encodeList(parsed.matchList)
            if (parsed.mode) values.mode = Model.normalizeMode(parsed.mode)
            if (values.region !== undefined || values.pinAddress !== undefined || values.blacklist !== undefined || values.matchList !== undefined || values.mode !== undefined)
              root.persistSettings(values)
          }
        }
        if (root.commandQueue.length > 0) {
          var next = root.commandQueue.shift()
          root.runQueuedCommand(next.args, next.after)
          return
        }
        root.busy = false
        root.refresh()
        if (reopen || root.pickShouldReopen) root.finishPickReopen()
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

        Item {
          id: header
          width: parent.width
          implicitHeight: Math.max(heroLabels.implicitHeight, powerSwitch.implicitHeight)
          readonly property color dim: Qt.darker(root.contentForeground, 1.4)

          Column {
            id: heroLabels
            anchors.left: parent.left
            anchors.right: powerSwitch.left
            anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "Instant Replay"
              textFormat: Text.PlainText
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              visible: text !== ""
              text: Model.plainLabel(Model.statusHeadline(root.status, root.configuredMode), 80).toUpperCase()
              textFormat: Text.PlainText
              wrapMode: Text.Wrap
              color: header.dim
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }

            Text {
              width: parent.width
              visible: text !== ""
              text: Model.plainLabel(Model.statusDetail(root.status), 80).toUpperCase()
              textFormat: Text.PlainText
              wrapMode: Text.Wrap
              color: header.dim
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }

          ToggleSwitch {
            id: powerSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: root.sessionOn
            busy: root.busy
            foreground: root.contentForeground
            onToggled: {
              if (root.busy) return
              root.sessionOn ? root.stopBuffer() : root.startBuffer()
            }
          }
        }

        Text {
          width: parent.width
          visible: root.lastError !== ""
          text: Model.plainLabel(root.lastError, 400)
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          color: Color.urgent
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Save clip"
            enabled: root.running && !root.busy
            bordered: true
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.save()
          }

          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Open clips"
            enabled: !root.busy && root.clipsFolderPath() !== ""
            bordered: true
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.openClipsFolder()
          }
        }

        Column {
          width: parent.width
          spacing: Style.space(4)
          visible: String(root.status.lastClip || "") !== ""
          height: visible ? implicitHeight : 0

          Text {
            text: "Last save"
            textFormat: Text.PlainText
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width - omacutButton.width - parent.spacing
              text: Model.plainLabel(root.status.lastClip, 256)
              textFormat: Text.PlainText
              elide: Text.ElideMiddle
              color: Qt.darker(root.contentForeground, 1.3)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              verticalAlignment: Text.AlignVCenter
              height: omacutButton.height
            }

            Button {
              id: omacutButton
              implicitWidth: Style.font.iconLarge + horizontalPadding * 2
              implicitHeight: Style.font.iconLarge + verticalPadding * 2
              text: ""
              tooltipText: "omacut"
              enabled: !root.busy
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.openLastClipInOmacut()

              Image {
                anchors.centerIn: parent
                width: Style.font.iconLarge
                height: Style.font.iconLarge
                fillMode: Image.PreserveAspectFit
                sourceSize.width: Math.round(width * Screen.devicePixelRatio)
                sourceSize.height: Math.round(height * Screen.devicePixelRatio)
                source: Quickshell.iconPath("omacut", true)
                asynchronous: true
              }
            }
          }
        }

        PanelSeparator {}

        ExtraGroup {
          title: "Replay"
          open: root.extrasConfigOpen
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onToggled: root.extrasConfigOpen = !root.extrasConfigOpen

          Text {
            text: "Output folder"
            textFormat: Text.PlainText
            color: Qt.darker(root.contentForeground, 1.5)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            TextField {
              id: outputDirField
              width: parent.width - browseFolderButton.width - parent.spacing
              text: root.configuredOutputDir
              placeholderText: root.status.outputDir !== "" ? Model.plainLabel(root.status.outputDir, 80) : "Videos/Replays"
              maximumLength: 512
              foreground: root.contentForeground
              onEditingFinished: {
                if (root.configuredOutputDir === text) return
                root.applySetting("outputDir", text)
              }
            }

            Button {
              id: browseFolderButton
              text: "Choose"
              enabled: !folderPickProc.running
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.pickOutputDir()
            }
          }

          ReplayDropdown {
            id: secondsDropdown
            width: parent.width
            label: "Replay Window"
            value: String(root.configuredSeconds)
            options: root.secondsChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("seconds", Model.boundedInteger(value, 60, Model.minSeconds(), Model.maxSeconds())) }
          }

          ReplayDropdown {
            id: audioDropdown
            width: parent.width
            label: "Audio"
            value: root.configuredAudio
            options: root.audioChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("audio", Model.normalizeAudio(value)) }
          }

          ReplayDropdown {
            id: clipResolutionDropdown
            width: parent.width
            label: "Resolution"
            value: root.configuredClipResolution
            options: root.clipResolutionChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("clipResolution", Model.normalizeClipResolution(value)) }
          }

          ReplayDropdown {
            id: clipScaleDropdown
            width: parent.width
            label: "Layout"
            value: root.configuredClipScale
            options: root.clipScaleChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("clipScale", Model.normalizeClipScale(value)) }
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

          Button {
            width: parent.width
            text: root.hotkeyCopyStatus !== "" ? root.hotkeyCopyStatus : "Copy keybinds"
            enabled: !root.busy
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onClicked: root.copyHotkeys()
          }
        }

        ExtraGroup {
          title: "Recording region"
          open: root.extrasModeOpen
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onToggled: root.extrasModeOpen = !root.extrasModeOpen

          ReplayDropdown {
            id: modeDropdown
            width: parent.width
            label: "Mode"
            value: root.configuredMode
            options: root.modeChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("mode", Model.normalizeMode(value)) }
          }

          ReplayDropdown {
            id: filterDropdown
            width: parent.width
            visible: root.configuredMode === "follow"
            height: visible ? implicitHeight : 0
            label: "Filter"
            value: root.configuredFilter
            options: root.filterChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("filter", Model.normalizeFilter(value)) }
          }

          ClassListEditor {
            width: parent.width
            visible: root.configuredMode === "follow" && root.configuredFilter === "allowlist"
            height: visible ? implicitHeight : 0
            title: "Allowlist"
            emptyText: "Empty allowlist"
            listSource: root.configuredMatchList
            panelOpen: root.opened
            busy: root.busy
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onRequestPick: root.pickMatchWindow()
            onEmptyList: root.applyMatchList("")
            onRemoveAt: function(index) {
              root.applyMatchList(Model.removeListItem(root.configuredMatchList, index))
            }
          }

          ClassListEditor {
            width: parent.width
            visible: root.configuredMode === "follow" && root.configuredFilter === "denylist"
            height: visible ? implicitHeight : 0
            title: "Blacklist"
            emptyText: "Empty blacklist"
            listSource: root.configuredBlacklist
            panelOpen: root.opened
            busy: root.busy
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onRequestPick: root.pickBlacklistWindow()
            onEmptyList: root.applyBlacklist("")
            onRemoveAt: function(index) {
              root.applyBlacklist(Model.removeListItem(root.configuredBlacklist, index))
            }
          }

          ReplayDropdown {
            id: monitorDropdown
            width: parent.width
            visible: root.configuredMode === "monitor"
            height: visible ? implicitHeight : 0
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
              text: String(root.status.subject || "") !== "" ? ("Pinned · " + Model.plainLabel(root.status.subject, 80)) : (root.configuredPinAddress !== "" ? ("Pinned · " + Model.plainLabel(root.configuredPinAddress, 32)) : "No window yet")
              textFormat: Text.PlainText
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
              text: root.configuredRegion !== "" ? Model.plainLabel(root.configuredRegion, 64) : "No rectangle yet"
              textFormat: Text.PlainText
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
        }

        ExtraGroup {
          title: "Encoder"
          open: root.extrasEncoderOpen
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onToggled: root.extrasEncoderOpen = !root.extrasEncoderOpen

          ReplayDropdown {
            id: codecDropdown
            width: parent.width
            label: "Codec"
            value: root.configuredCodec
            options: root.codecChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("codec", Model.normalizeCodec(value)) }
          }

          ReplayDropdown {
            id: fpsDropdown
            width: parent.width
            label: "FPS"
            value: String(root.configuredFps)
            options: root.fpsChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("fps", Model.boundedInteger(value, 60, Model.minFps(), Model.maxFps())) }
          }

          ReplayDropdown {
            id: qualityDropdown
            width: parent.width
            label: "Quality"
            value: String(root.configuredQuality)
            options: root.qualityChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("quality", Model.boundedInteger(value, 40000, Model.minQuality(), Model.maxQuality())) }
          }

          ReplayDropdown {
            id: framerateDropdown
            width: parent.width
            label: "Framerate mode"
            value: root.configuredFramerateMode
            options: root.framerateModeChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("framerateMode", Model.normalizeFramerateMode(value)) }
          }

          ReplayDropdown {
            id: bitrateDropdown
            width: parent.width
            label: "Bitrate mode"
            value: root.configuredBitrateMode
            options: root.bitrateModeChoices
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onChanged: function(value) { root.applySetting("bitrateMode", Model.normalizeBitrateMode(value)) }
          }
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
          textFormat: Text.PlainText
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

    PanelSeparator {
      foreground: extra.foreground
      visible: extra.open
      height: extra.open ? implicitHeight : 0
    }
  }
}

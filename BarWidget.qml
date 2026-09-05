import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.anthonyposchen.shadowplay"

  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property bool running: panelLoader.item ? panelLoader.item.running === true : false
  readonly property string helperPath: decodeURIComponent(String(Qt.resolvedUrl("bin/omarchy-shadowplay")).replace(/^file:\/\//, ""))

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root.barIdentity
    target.helperPath = root.helperPath
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function refresh() { if (panelLoader.item) panelLoader.item.refresh() }
  function save() { if (panelLoader.item) panelLoader.item.save() }
  function start() { if (panelLoader.item) panelLoader.item.startBuffer() }
  function stop() { if (panelLoader.item) panelLoader.item.stopBuffer() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "io.github.anthonyposchen.shadowplay"
    function refresh() { root.broadcast("refresh") }
    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
    function save() { root.broadcast("save") }
    function start() { root.broadcast("start") }
    function stop() { root.broadcast("stop") }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰑋"
    opacity: root.running ? 1.0 : 0.48
    tooltipText: root.running ? "Save replay" : "ShadowPlay"

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) {
        root.refresh()
        return
      }
      if (buttonCode === Qt.RightButton) {
        root.toggle()
        return
      }
      if (root.running) root.save()
      else root.toggle()
    }
  }
}

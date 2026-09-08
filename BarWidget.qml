import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.anthonyposchen.instant-replay"

  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property bool running: panelLoader.item ? panelLoader.item.running === true : false
  readonly property int savingCount: panelLoader.item ? panelLoader.item.savingCount : 0
  readonly property string helperPath: decodeURIComponent(String(Qt.resolvedUrl("bin/omarchy-instant-replay")).replace(/^file:\/\//, ""))

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

  function primaryAction() {
    if (root.running) root.save()
    else root.start()
  }

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
    target: "io.github.anthonyposchen.instant-replay"
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
    iconComponent: replayMark
    active: root.running || root.savingCount > 0
    useActiveColor: false
    dimmed: !root.running && root.savingCount === 0
    fontSize: Style.font.iconLarge
    opticalSize: Style.bar.iconCanvas + 4
    slotSize: Style.bar.iconSlot
    tooltipText: root.savingCount > 0
      ? (root.savingCount === 1 ? "Saving clip" : ("Saving " + Math.min(root.savingCount, 99) + " clips"))
      : (root.running ? "Save replay" : "Start replay buffer")

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) {
        root.refresh()
        return
      }
      if (buttonCode === Qt.RightButton) {
        root.toggle()
        return
      }
      root.primaryAction()
    }
  }

  Component {
    id: replayMark
    Item {
      Rectangle {
        id: disc
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.76
        height: width
        radius: width / 2
        color: button.active ? button.activeColor : button.foreground

        Behavior on color {
          ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
      }

      OpticalGlyph {
        anchors.centerIn: disc
        width: disc.width * 0.82
        height: disc.height * 0.82
        text: "󰑙"
        fontFamily: button.fontFamily
        fontSize: disc.width * 0.68
        color: "#111111"
      }
    }
  }

  Rectangle {
    visible: root.savingCount > 0
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: 1
    anchors.bottomMargin: 1
    width: Math.max(Style.space(14), badgeLabel.implicitWidth + Style.space(6))
    height: Math.max(Style.space(14), badgeLabel.implicitHeight + Style.space(2))
    radius: height / 2
    color: Color.urgent
    z: 1

    Text {
      id: badgeLabel
      anchors.centerIn: parent
      text: root.savingCount > 9 ? "9+" : String(root.savingCount)
      textFormat: Text.PlainText
      color: Color.background
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }
}

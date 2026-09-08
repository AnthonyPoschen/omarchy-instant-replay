import QtQuick
import QtQuick.Shapes
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
        width: Math.min(parent.width, parent.height) * 0.68
        height: width
        radius: width / 2
        color: button.active ? button.activeColor : button.foreground

        Behavior on color {
          ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
      }

      Item {
        id: loop
        anchors.centerIn: disc
        width: disc.width * 0.78
        height: width

        readonly property color ink: "#111111"
        readonly property real sw: Math.max(2.4, width * 0.22)
        readonly property real r: Math.max(1.5, (width - sw) * 0.34)
        readonly property real cx: width / 2
        readonly property real cy: height / 2
        readonly property real startDeg: 48
        readonly property real sweepDeg: 276
        readonly property real endRad: (startDeg + sweepDeg) * Math.PI / 180
        readonly property real ex: cx + r * Math.cos(endRad)
        readonly property real ey: cy + r * Math.sin(endRad)
        readonly property real tx: -Math.sin(endRad)
        readonly property real ty: Math.cos(endRad)
        readonly property real al: sw * 1.7
        readonly property real aw: sw * 1.25
        readonly property real tipX: ex + tx * sw * 0.2
        readonly property real tipY: ey + ty * sw * 0.2
        readonly property real play: width * 0.17

        Shape {
          anchors.fill: parent
          antialiasing: true
          preferredRendererType: Shape.CurveRenderer

          ShapePath {
            strokeColor: loop.ink
            strokeWidth: loop.sw
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
              centerX: loop.cx
              centerY: loop.cy
              radiusX: loop.r
              radiusY: loop.r
              startAngle: loop.startDeg
              sweepAngle: loop.sweepDeg
            }
          }

          ShapePath {
            fillColor: loop.ink
            strokeWidth: 0
            startX: loop.tipX
            startY: loop.tipY
            PathLine {
              x: loop.tipX - loop.tx * loop.al - loop.ty * loop.aw
              y: loop.tipY - loop.ty * loop.al + loop.tx * loop.aw
            }
            PathLine {
              x: loop.tipX - loop.tx * loop.al + loop.ty * loop.aw
              y: loop.tipY - loop.ty * loop.al - loop.tx * loop.aw
            }
            PathLine { x: loop.tipX; y: loop.tipY }
          }

          ShapePath {
            fillColor: loop.ink
            strokeWidth: 0
            startX: loop.cx - loop.play * 0.45
            startY: loop.cy - loop.play
            PathLine { x: loop.cx + loop.play; y: loop.cy }
            PathLine { x: loop.cx - loop.play * 0.45; y: loop.cy + loop.play }
            PathLine { x: loop.cx - loop.play * 0.45; y: loop.cy - loop.play }
          }
        }
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

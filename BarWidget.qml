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

  function panelItem() {
    return panelLoader.item
  }

  function panelIsOpen() {
    var panel = root.panelItem()
    return !!(panel && panel.opened)
  }

  function showPanel() {
    var panel = root.panelItem()
    if (panel) panel.open()
  }

  function hidePanel() {
    panelOpenTimer.stop()
    justClosedTimer.restart()
    var panel = root.panelItem()
    if (panel) panel.close()
  }

  function refreshStatus() {
    if (panelLoader.item) panelLoader.item.refresh()
  }

  function saveClip() {
    if (panelLoader.item) panelLoader.item.save()
  }

  function startBuffer() {
    if (panelLoader.item) panelLoader.item.startBuffer()
  }

  function stopBuffer() {
    if (panelLoader.item) panelLoader.item.stopBuffer()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  // Shape contract for Bar.findPanelWidget. Names must not match IpcHandler
  // methods — those shadow JS functions on this object, so root.open() never
  // reached the panel.
  function open() { root.showPanel() }
  function close() { root.hidePanel() }

  Timer {
    id: panelOpenTimer
    interval: 100
    repeat: false
    onTriggered: {
      if (justClosedTimer.running) return
      root.showPanel()
    }
  }

  // KeyboardPanel's dismiss overlay and the bar slot overlay can both see
  // the same left-click. Dismiss closes, then this would open again.
  Timer {
    id: justClosedTimer
    interval: 150
    repeat: false
  }

  // Read opened off the panel object, not BarWidget.opened: a Loader
  // ternary binding can stay false after controller.show(), so a second
  // click kept taking the open path.
  Connections {
    target: panelLoader.item
    function onOpenedChanged() {
      if (panelLoader.item && panelLoader.item.opened) return
      panelOpenTimer.stop()
      justClosedTimer.restart()
    }
  }

  // Bar overlay left-clicks this. Left toggles Settings. Right saves.
  // Delay the open so KeyboardPanel's Exclusive dismiss overlay does not
  // eat the same click; close is immediate.
  function triggerPress(button) {
    if (button === Qt.MiddleButton) {
      root.refreshStatus()
      return
    }
    if (button === Qt.RightButton) {
      root.saveClip()
      return
    }
    root.togglePanel()
  }

  function togglePanel() {
    if (root.panelIsOpen() || justClosedTimer.running) {
      root.hidePanel()
      return
    }
    panelOpenTimer.restart()
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
    function refresh() { root.broadcast("refreshStatus") }
    function open() { root.showPanel() }
    function close() { root.hidePanel() }
    function show() { root.showPanel() }
    function hide() { root.hidePanel() }
    function toggle() { root.togglePanel() }
    function save() { root.broadcast("saveClip") }
    function start() { root.broadcast("startBuffer") }
    function stop() { root.broadcast("stopBuffer") }
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
      : "Left-click settings · right-click save"

    onPressed: function(buttonCode) {
      root.triggerPress(buttonCode)
    }
  }

  Component {
    id: replayMark
    ReplayMarkRewind {
      anchors.fill: parent
      discColor: button.active ? button.activeColor : button.foreground
      saving: root.savingCount > 0
    }
  }
}

import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Allowlist / denylist editor: a body-weight title, then class rows and
// Pick / Empty with tight spacing so they read as one group.
Column {
  id: root

  property string title: ""
  property string emptyText: "Empty list"
  property var listSource
  property bool busy: false
  property bool panelOpen: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int pageSize: 5

  readonly property int loadedCount: Model.listLength(listSource)
  readonly property int itemCount: Math.max(itemModel.count, loadedCount)
  readonly property bool needPager: itemCount > pageSize
  readonly property int pageCount: Math.max(1, Math.ceil(itemCount / Math.max(1, pageSize)))
  readonly property int safePage: Math.max(0, Math.min(page, pageCount - 1))
  readonly property int pageStart: safePage * Math.max(1, pageSize)
  readonly property int pageItemCount: Math.min(pageSize, Math.max(0, itemCount - pageStart))
  readonly property int removeSize: Style.space(28)
  readonly property string titleText: needPager
    ? (title + " · " + (pageStart + 1) + "–" + (pageStart + pageItemCount) + " of " + itemCount)
    : title

  property int page: 0
  property int lastItemCount: 0

  signal requestPick()
  signal emptyList()
  signal removeAt(int index)

  spacing: Style.space(6)

  ListModel {
    id: itemModel
  }

  function rowValue(index) {
    if (index < 0 || index >= itemModel.count) return ""
    var row = itemModel.get(index)
    return row && row.value ? String(row.value) : ""
  }

  function rebuild() {
    if (!itemModel)
      return
    var previous = lastItemCount
    itemModel.clear()
    var n = Model.listLength(listSource)
    var i
    for (i = 0; i < n; i++) {
      var item = Model.listItem(listSource, i)
      if (item) itemModel.append({ value: item })
    }
    var pages = Math.max(1, Math.ceil(Math.max(itemModel.count, n) / Math.max(1, pageSize)))
    if (n > previous && previous > 0)
      page = pages - 1
    else if (page > pages - 1)
      page = pages - 1
    lastItemCount = Math.max(itemModel.count, n)
  }

  onListSourceChanged: rebuild()
  onPanelOpenChanged: if (panelOpen) Qt.callLater(rebuild)
  Component.onCompleted: rebuild()

  Row {
    width: parent.width
    spacing: Style.space(6)
    height: Math.max(titleLabel.implicitHeight, root.removeSize)

    Text {
      id: titleLabel
      width: parent.width - (root.needPager ? (root.removeSize * 2 + parent.spacing * 2) : 0)
      text: root.titleText
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
      verticalAlignment: Text.AlignVCenter
      height: parent.height
    }

    Button {
      width: root.needPager ? root.removeSize : 0
      height: root.removeSize
      opacity: root.needPager ? 1 : 0
      enabled: root.needPager && !root.busy && root.safePage > 0
      bordered: true
      text: "‹"
      tooltipText: "Previous page"
      foreground: root.foreground
      fontFamily: root.fontFamily
      horizontalPadding: 0
      verticalPadding: 0
      onClicked: root.page = Math.max(0, root.safePage - 1)
    }

    Button {
      width: root.needPager ? root.removeSize : 0
      height: root.removeSize
      opacity: root.needPager ? 1 : 0
      enabled: root.needPager && !root.busy && root.safePage < root.pageCount - 1
      bordered: true
      text: "›"
      tooltipText: "Next page"
      foreground: root.foreground
      fontFamily: root.fontFamily
      horizontalPadding: 0
      verticalPadding: 0
      onClicked: root.page = Math.min(root.pageCount - 1, root.safePage + 1)
    }
  }

  Text {
    width: parent.width
    visible: root.itemCount === 0
    height: visible ? implicitHeight : 0
    text: "None yet"
    textFormat: Text.PlainText
    color: Qt.darker(root.foreground, 1.5)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Repeater {
    model: root.pageItemCount
    delegate: Row {
      width: root.width
      spacing: Style.space(8)

      readonly property int absIndex: root.pageStart + index

      Text {
        width: parent.width - root.removeSize - parent.spacing
        text: Model.plainLabel(root.rowValue(absIndex), 128)
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        verticalAlignment: Text.AlignVCenter
        height: root.removeSize
      }

      Button {
        width: root.removeSize
        height: root.removeSize
        bordered: true
        text: "X"
        tooltipText: "Remove"
        enabled: !root.busy
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.body
        horizontalPadding: 0
        verticalPadding: 0
        onClicked: root.removeAt(parent.absIndex)
      }
    }
  }

  Row {
    width: parent.width
    spacing: Style.space(8)

    Button {
      width: emptyListButton.visible ? parent.width - emptyListButton.width - parent.spacing : parent.width
      text: "Pick window"
      enabled: !root.busy
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.requestPick()
    }

    Button {
      id: emptyListButton
      visible: root.itemCount > 0
      width: visible ? implicitWidth : 0
      text: root.emptyText
      enabled: !root.busy
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.emptyList()
    }
  }
}

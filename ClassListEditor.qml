import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Allowlist / denylist editor: class rows first, then a faint rule, then
// Pick window / empty. Pages after five items.
Column {
  id: root

  property string title: ""
  property string emptyText: "Empty list"
  property string itemsCsv: ""
  property bool busy: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int pageSize: 5

  readonly property var items: Model.stringList(itemsCsv)
  readonly property int itemCount: items.length
  readonly property int pageCount: Math.max(1, Math.ceil(itemCount / Math.max(1, pageSize)))
  readonly property int safePage: Math.max(0, Math.min(page, pageCount - 1))
  readonly property int pageStart: safePage * Math.max(1, pageSize)
  readonly property int pageItemCount: Math.min(pageSize, Math.max(0, itemCount - pageStart))
  readonly property int removeSize: Style.space(28)

  property int page: 0
  property int lastItemCount: 0

  signal requestPick()
  signal emptyList()
  signal removeAt(int index)

  spacing: Style.space(6)

  onItemCountChanged: {
    var pages = Math.max(1, Math.ceil(itemCount / Math.max(1, pageSize)))
    if (itemCount > lastItemCount && lastItemCount > 0)
      page = pages - 1
    else if (page > pages - 1)
      page = pages - 1
    lastItemCount = itemCount
  }

  PanelSectionHeader {
    text: root.title
    foreground: root.foreground
    fontFamily: root.fontFamily
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
        text: Model.plainLabel(root.items[absIndex] || "", 128)
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
    visible: root.itemCount > root.pageSize
    height: visible ? implicitHeight : 0

    Button {
      id: prevPageButton
      width: root.removeSize
      height: root.removeSize
      bordered: true
      text: "<"
      tooltipText: "Previous page"
      enabled: !root.busy && root.safePage > 0
      foreground: root.foreground
      fontFamily: root.fontFamily
      horizontalPadding: 0
      verticalPadding: 0
      onClicked: root.page = Math.max(0, root.safePage - 1)
    }

    Text {
      width: parent.width - prevPageButton.width - nextPageButton.width - parent.spacing * 2
      height: root.removeSize
      text: root.pageItemCount === 0 ? "" : ((root.pageStart + 1) + "–" + (root.pageStart + root.pageItemCount) + " of " + root.itemCount)
      textFormat: Text.PlainText
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    Button {
      id: nextPageButton
      width: root.removeSize
      height: root.removeSize
      bordered: true
      text: ">"
      tooltipText: "Next page"
      enabled: !root.busy && root.safePage < root.pageCount - 1
      foreground: root.foreground
      fontFamily: root.fontFamily
      horizontalPadding: 0
      verticalPadding: 0
      onClicked: root.page = Math.min(root.pageCount - 1, root.safePage + 1)
    }
  }

  PanelSeparator {
    foreground: root.foreground
    strength: 0.14
  }

  Button {
    width: parent.width
    text: "Pick window"
    enabled: !root.busy
    foreground: root.foreground
    fontFamily: root.fontFamily
    onClicked: root.requestPick()
  }

  Button {
    width: parent.width
    text: root.emptyText
    enabled: !root.busy && root.itemCount > 0
    foreground: root.foreground
    fontFamily: root.fontFamily
    onClicked: root.emptyList()
  }
}

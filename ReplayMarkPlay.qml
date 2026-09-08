import QtQuick
import qs.Commons
import qs.Ui

// Backup bar mark: themed disc with a filled play triangle.
// In BarWidget, point iconComponent at ReplayMarkPlay to restore this.
Item {
  property color discColor: "#f4f1ea"

  Rectangle {
    id: disc
    anchors.centerIn: parent
    width: Math.min(parent.width, parent.height) * 0.68
    height: width
    radius: width / 2
    color: discColor

    Behavior on color {
      ColorAnimation { duration: 140; easing.type: Easing.OutCubic }
    }
  }

  OpticalGlyph {
    anchors.centerIn: disc
    anchors.horizontalCenterOffset: disc.width * 0.05
    width: disc.width
    height: disc.height
    text: "󰐊"
    fontFamily: Style.font.family
    fontSize: disc.width * 0.78
    color: "#111111"
  }
}

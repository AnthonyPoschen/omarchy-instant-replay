import QtQuick

// Themed disc: rewind ◀◀ when idle/live, three dots while a Clip is saving.
Item {
  property color discColor: "#f4f1ea"
  property bool saving: false
  property int heavyDot: 0

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

  Timer {
    interval: 280
    repeat: true
    running: saving
    onTriggered: heavyDot = (heavyDot + 1) % 3
  }

  onSavingChanged: {
    if (!saving)
      heavyDot = 0
    mark.requestPaint()
  }
  onHeavyDotChanged: mark.requestPaint()

  Canvas {
    id: mark
    anchors.centerIn: disc
    width: disc.width
    height: width
    antialiasing: true
    renderStrategy: Canvas.Cooperative

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      var w = width
      var h = height
      ctx.reset()
      if (w < 4 || h < 4)
        return

      var ink = "#111111"
      ctx.fillStyle = ink
      var cy = h / 2

      if (saving) {
        var gap = w * 0.26
        var cx = w / 2
        var light = Math.max(1.15, w * 0.09)
        var heavy = Math.max(1.7, w * 0.15)
        for (var i = 0; i < 3; i++) {
          var r = (i === heavyDot) ? heavy : light
          var x = cx + (i - 1) * gap
          ctx.beginPath()
          ctx.arc(x, cy, r, 0, Math.PI * 2)
          ctx.fill()
        }
        return
      }

      var triH = h * 0.58
      var triW = w * 0.34
      var overlap = triW * 0.12
      var x0 = w * 0.16
      function triangle(x) {
        ctx.beginPath()
        ctx.moveTo(x, cy)
        ctx.lineTo(x + triW, cy - triH / 2)
        ctx.lineTo(x + triW, cy + triH / 2)
        ctx.closePath()
        ctx.fill()
      }
      triangle(x0)
      triangle(x0 + triW - overlap)
    }
  }
}

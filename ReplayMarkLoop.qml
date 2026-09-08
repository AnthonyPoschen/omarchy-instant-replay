import QtQuick

// Themed disc with a thick replay loop (arc + arrow + play). Drawn on
// Canvas so stroke weight stays even at bar size.
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

  Canvas {
    id: loop
    anchors.centerIn: disc
    width: disc.width * 0.82
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

      var cx = w / 2
      var cy = h / 2
      var ink = "#111111"
      var sw = Math.max(2.0, w * 0.17)
      var r = Math.max(2, (w - sw) * 0.34)
      // Gap at 12–2 o'clock, arrow at 12 pointing right (Material replay).
      var start = 330 * Math.PI / 180
      var end = 270 * Math.PI / 180

      ctx.strokeStyle = ink
      ctx.fillStyle = ink
      ctx.lineWidth = sw
      ctx.lineCap = "round"
      ctx.lineJoin = "round"

      ctx.beginPath()
      ctx.arc(cx, cy, r, start, end, false)
      ctx.stroke()

      var tx = -Math.sin(end)
      var ty = Math.cos(end)
      var ex = cx + r * Math.cos(end)
      var ey = cy + r * Math.sin(end)
      var al = sw * 1.25
      var aw = sw * 0.85
      var tipX = ex + tx * sw * 0.2
      var tipY = ey + ty * sw * 0.2
      ctx.beginPath()
      ctx.moveTo(tipX, tipY)
      ctx.lineTo(tipX - tx * al - ty * aw, tipY - ty * al + tx * aw)
      ctx.lineTo(tipX - tx * al + ty * aw, tipY - ty * al - tx * aw)
      ctx.closePath()
      ctx.fill()

      var pw = w * 0.22
      var ph = h * 0.26
      ctx.beginPath()
      ctx.moveTo(cx - pw * 0.28, cy - ph / 2)
      ctx.lineTo(cx + pw * 0.62, cy)
      ctx.lineTo(cx - pw * 0.28, cy + ph / 2)
      ctx.closePath()
      ctx.fill()
    }
  }
}

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
      var sw = Math.max(2.0, w * 0.16)
      var r = Math.max(2, (w - sw) * 0.33)
      var start = Math.PI * 0.28
      var sweep = Math.PI * 1.52
      var end = start + sweep

      ctx.strokeStyle = ink
      ctx.fillStyle = ink
      ctx.lineWidth = sw
      ctx.lineCap = "round"
      ctx.lineJoin = "round"

      ctx.beginPath()
      ctx.arc(cx, cy, r, start, end, false)
      ctx.stroke()

      var tx = Math.sin(end)
      var ty = -Math.cos(end)
      var ex = cx + r * Math.cos(end)
      var ey = cy + r * Math.sin(end)
      var al = sw * 1.35
      var aw = sw * 0.9
      var tipX = ex + tx * sw * 0.12
      var tipY = ey + ty * sw * 0.12
      ctx.beginPath()
      ctx.moveTo(tipX, tipY)
      ctx.lineTo(tipX - tx * al - ty * aw, tipY - ty * al + tx * aw)
      ctx.lineTo(tipX - tx * al + ty * aw, tipY - ty * al - tx * aw)
      ctx.closePath()
      ctx.fill()

      var pw = w * 0.24
      var ph = h * 0.28
      ctx.beginPath()
      ctx.moveTo(cx - pw * 0.32, cy - ph / 2)
      ctx.lineTo(cx + pw * 0.58, cy)
      ctx.lineTo(cx - pw * 0.32, cy + ph / 2)
      ctx.closePath()
      ctx.fill()
    }
  }
}

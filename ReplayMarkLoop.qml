import QtQuick

// Themed disc with a thick replay loop. The arrow sits on the stroke end;
// there is no play triangle in the middle at bar size.
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
    width: disc.width * 0.88
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
      var sw = Math.max(2.0, w * 0.19)
      var r = Math.max(2, (w - sw) * 0.30)
      // Tighter hook, larger head at 12 o'clock pointing left (rewind).
      var start = 150 * Math.PI / 180
      var end = 270 * Math.PI / 180
      var c = Math.cos(end)
      var s = Math.sin(end)
      var px = cx + r * c
      var py = cy + r * s
      var tx = s
      var ty = -c
      var len = sw * 2.9
      var hw = sw * 2.0

      ctx.strokeStyle = ink
      ctx.fillStyle = ink
      ctx.lineWidth = sw
      ctx.lineCap = "butt"
      ctx.lineJoin = "round"

      ctx.beginPath()
      ctx.arc(cx, cy, r, start, end, true)
      ctx.stroke()

      var sx = cx + r * Math.cos(start)
      var sy = cy + r * Math.sin(start)
      ctx.beginPath()
      ctx.arc(sx, sy, sw / 2, 0, Math.PI * 2)
      ctx.fill()

      ctx.beginPath()
      ctx.moveTo(px + tx * len, py + ty * len)
      ctx.lineTo(px - tx * sw * 0.4 - ty * hw, py - ty * sw * 0.4 + tx * hw)
      ctx.lineTo(px - tx * sw * 0.4 + ty * hw, py - ty * sw * 0.4 - tx * hw)
      ctx.closePath()
      ctx.fill()
    }
  }
}

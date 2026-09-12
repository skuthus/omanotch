import QtQuick

// The concave corner where the island meets the screen edge, so a widened
// island looks carved out of the bezel rather than pasted on top of it.
Canvas {
  id: root

  property bool mirrored: false
  property color fill: "black"

  width: 10
  height: 10
  antialiasing: true

  onFillChanged: requestPaint()
  onMirroredChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    ctx.fillStyle = root.fill
    ctx.beginPath()
    if (!root.mirrored) {
      ctx.moveTo(0, 0)
      ctx.lineTo(width, 0)
      ctx.lineTo(width, height)
      ctx.arc(0, height, width, 0, -Math.PI / 2, true)
    } else {
      ctx.moveTo(width, 0)
      ctx.lineTo(0, 0)
      ctx.lineTo(0, height)
      ctx.arc(width, height, width, Math.PI, 1.5 * Math.PI, false)
    }
    ctx.closePath()
    ctx.fill()
  }
}

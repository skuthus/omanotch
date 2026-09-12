import QtQuick

// A glyph inside a thin ring that shows a 0..1 level. Shared by the
// dashboard dials and the OSD pill so levels read the same everywhere.
Item {
  id: root

  property var notch: null
  property string icon: ""
  property real level: 0
  property bool active: true
  property real stroke: 2.5
  property int glyphSize: notch ? notch.iconSize - 4 : 14

  Canvas {
    id: ring
    anchors.fill: parent
    antialiasing: true
    readonly property real fraction: Math.max(0, Math.min(1, root.level))
    readonly property color trackColor: root.notch.track
    readonly property color fillColor: root.active ? root.notch.accent : root.notch.inkDim
    onFractionChanged: requestPaint()
    onFillColorChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.clearRect(0, 0, width, height)
      var cx = width / 2, cy = height / 2
      var r = cx - root.stroke / 2 - 0.5
      var start = -Math.PI / 2
      ctx.lineWidth = root.stroke
      ctx.lineCap = "round"
      ctx.strokeStyle = trackColor
      ctx.beginPath()
      ctx.arc(cx, cy, r, 0, Math.PI * 2, false)
      ctx.stroke()
      if (fraction > 0.005) {
        ctx.strokeStyle = fillColor
        ctx.beginPath()
        ctx.arc(cx, cy, r, start, start + Math.PI * 2 * fraction, false)
        ctx.stroke()
      }
    }
  }

  Text {
    anchors.centerIn: parent
    text: root.icon
    color: root.active ? root.notch.ink : root.notch.inkDim
    font.family: root.notch.fontFamily
    font.pixelSize: root.glyphSize
    textFormat: Text.PlainText
  }
}

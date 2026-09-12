import QtQuick

// A Control Center style circle with a thin ring showing a level. Scroll
// over it to adjust, click for its secondary action (mute, cycle).
Item {
  id: root

  property var notch: null
  property string icon: ""
  property real level: 0          // 0..1
  property bool active: true      // false draws the ring dimmed (muted, off)
  signal adjust(real delta)       // +1 / -1 per notch
  signal tapped()

  width: notch ? notch.toggleSize : 28
  height: width

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: hover.containsMouse ? root.notch.trackHover : root.notch.track
    Behavior on color { ColorAnimation { duration: 120 } }
  }

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
      var stroke = 2.5
      var r = cx - stroke / 2 - 0.5
      var start = -Math.PI / 2
      ctx.lineWidth = stroke
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
    font.pixelSize: root.notch.iconSize - 4
    textFormat: Text.PlainText
  }

  MouseArea {
    id: hover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.tapped()
    // Trackpads send many small deltas; accumulate to one step per 40 units.
    property real acc: 0
    onWheel: function(wheel) {
      acc += wheel.angleDelta.y
      if (acc >= 40) { acc = 0; root.adjust(1) }
      else if (acc <= -40) { acc = 0; root.adjust(-1) }
      wheel.accepted = true
    }
  }
}

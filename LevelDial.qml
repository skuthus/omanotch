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

  LevelRing {
    anchors.fill: parent
    notch: root.notch
    icon: root.icon
    level: root.level
    active: root.active
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

import QtQuick

// A row of level bars. Levels arrive from the notch (cava or the fallback
// animation) so every view draws the same signal.
Item {
  id: root

  property var levels: []
  property int bars: 4
  property color color: "white"
  property int barWidth: 3
  property int gap: 2
  property real minFraction: 0.12

  implicitWidth: bars * barWidth + (bars - 1) * gap
  implicitHeight: 16

  Row {
    anchors.centerIn: parent
    spacing: root.gap
    Repeater {
      model: root.bars
      Rectangle {
        required property int index
        width: root.barWidth
        radius: root.barWidth / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.color
        height: Math.max(root.barWidth, Math.round(root.height * Math.max(root.minFraction, Number(root.levels[index]) || 0)))
        Behavior on height { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
      }
    }
  }
}

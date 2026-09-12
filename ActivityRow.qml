import QtQuick

// A live activity in the notch: a pulsing dot and glyph on the leading ear,
// a short status on the trailing ear. Click anywhere on it to end it.
Item {
  id: root

  property var notch: null
  property string icon: ""
  property string label: ""
  property bool pulsing: true

  readonly property real earWidth: Math.max(0, (width - (notch ? notch.notchWidth : 0)) / 2)

  Item {
    x: 0
    width: root.earWidth
    height: parent.height
    Row {
      anchors.centerIn: parent
      spacing: 6
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 7
        height: 7
        radius: 3.5
        color: root.notch.urgentInk
        opacity: root.pulsing ? 1 : 0.6
        SequentialAnimation on opacity {
          running: root.pulsing && root.visible
          loops: Animation.Infinite
          NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.icon
        color: root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.iconSize - 2
        textFormat: Text.PlainText
      }
    }
  }

  Item {
    x: root.width - width
    width: root.earWidth
    height: parent.height
    Text {
      anchors.centerIn: parent
      text: root.label
      color: root.notch.inkDim
      font.family: root.notch.fontFamily
      font.pixelSize: root.notch.captionSize
      font.weight: Font.Medium
      textFormat: Text.PlainText
    }
  }
}

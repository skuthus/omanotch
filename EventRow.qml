import QtQuick

// One-row island content for OSD, battery, AirPods and status flashes: a
// glyph on the left ear, the readout on the right ear, the notch between.
Item {
  id: root

  property var notch: null
  property var event: null

  readonly property real earWidth: Math.max(0, (width - (notch ? notch.notchWidth : 0)) / 2)
  readonly property bool progress: event ? event.hasProgress === true : false
  readonly property string title: event ? String(event.title || "") : ""
  readonly property string message: event ? String(event.message || "") : ""
  readonly property bool urgent: event ? event.urgent === true : false

  // Left ear: the glyph, centred.
  Item {
    x: 0
    width: root.earWidth
    height: parent.height
    Text {
      anchors.centerIn: parent
      text: root.event ? String(root.event.icon || "") : ""
      color: root.urgent ? root.notch.urgentInk : root.notch.ink
      font.family: root.notch.fontFamily
      font.pixelSize: root.notch.iconSize
      textFormat: Text.PlainText
    }
  }

  // Right ear: progress bar and percentage, or title and message.
  Item {
    x: root.width - width
    width: root.earWidth
    height: parent.height

    Row {
      visible: root.progress
      anchors.centerIn: parent
      spacing: root.notch.gap
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(20, root.earWidth - root.notch.pad * 2 - percentLabel.width - parent.spacing)
        height: root.notch.trackHeight
        radius: height / 2
        color: root.notch.track
        Rectangle {
          height: parent.height
          radius: parent.radius
          width: parent.width * (root.progress ? root.event.value / root.event.max : 0)
          color: root.notch.accent
          Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
      }
      Text {
        id: percentLabel
        anchors.verticalCenter: parent.verticalCenter
        width: root.notch.percentWidth
        horizontalAlignment: Text.AlignRight
        text: root.progress ? root.message : ""
        color: root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.bodySize
        font.bold: true
        textFormat: Text.PlainText
      }
    }

    Row {
      visible: !root.progress
      anchors.centerIn: parent
      spacing: root.notch.gap / 2
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.title
        visible: text !== ""
        color: root.urgent ? root.notch.urgentInk : root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.bodySize
        font.bold: true
        elide: Text.ElideRight
        maximumLineCount: 1
        width: Math.min(implicitWidth, root.earWidth - root.notch.pad * 2)
        textFormat: Text.PlainText
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.message
        visible: text !== ""
        color: root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.bodySize
        elide: Text.ElideRight
        maximumLineCount: 1
        width: Math.min(implicitWidth, root.earWidth - root.notch.pad * 2)
        textFormat: Text.PlainText
      }
    }
  }
}

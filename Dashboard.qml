import QtQuick

// What hovering shows when nothing is playing: date and battery on the
// ears, a big clock and the quick toggles below the notch.
Item {
  id: root

  property var notch: null

  readonly property real earWidth: Math.max(0, (width - (notch ? notch.notchWidth : 0)) / 2)
  readonly property int strip: notch ? notch.notchHeight : 32

  property date now: new Date()
  Timer {
    interval: 1000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  // Left ear: the date.
  Item {
    x: 0
    width: root.earWidth
    height: root.strip
    Text {
      anchors.centerIn: parent
      text: Qt.formatDate(root.now, "ddd d MMM")
      color: root.notch.inkDim
      font.family: root.notch.fontFamily
      font.pixelSize: root.notch.captionSize
      textFormat: Text.PlainText
    }
  }

  // Right ear: battery.
  Item {
    x: root.width - width
    width: root.earWidth
    height: root.strip
    Row {
      anchors.centerIn: parent
      spacing: root.notch.gap / 2
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.notch.batteryIcon
        color: root.notch.batteryLow ? root.notch.urgentInk : root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.captionSize + 2
        textFormat: Text.PlainText
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.notch.batteryPercent >= 0 ? root.notch.batteryPercent + "%" : ""
        color: root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.captionSize
        textFormat: Text.PlainText
      }
    }
  }

  Item {
    x: root.notch.pad
    y: root.strip
    width: root.width - root.notch.pad * 2
    height: root.height - root.strip

    Column {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0
      // Click the clock to switch between 12 and 24 hour time.
      Text {
        text: Qt.formatTime(root.now, root.notch.clockFormat)
        color: clockTap.pressed ? root.notch.accent : root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.displaySize
        font.bold: true
        textFormat: Text.PlainText
        TapHandler {
          id: clockTap
          gesturePolicy: TapHandler.ReleaseWithinBounds
          onTapped: root.notch.toggleClockFormat()
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
      }
      Text {
        text: root.notch.batteryDetail
        visible: text !== ""
        color: root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.captionSize
        textFormat: Text.PlainText
      }
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: root.notch.gap

      Repeater {
        model: root.notch.toggles
        Rectangle {
          id: toggle
          required property var modelData
          width: root.notch.toggleSize
          height: root.notch.toggleSize
          radius: Math.round(width * 0.3)
          color: modelData.active ? root.notch.accentFill : root.notch.track
          border.width: 1
          border.color: modelData.active ? root.notch.accent : "transparent"
          Text {
            anchors.centerIn: parent
            text: toggle.modelData.icon
            color: toggle.modelData.active ? root.notch.accent : root.notch.ink
            font.family: root.notch.fontFamily
            font.pixelSize: root.notch.iconSize
            textFormat: Text.PlainText
          }
          TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: root.notch.runToggle(toggle.modelData.key) }
          HoverHandler { id: toggleHover; cursorShape: Qt.PointingHandCursor }
          Text {
            anchors.top: parent.bottom
            anchors.topMargin: 2
            anchors.horizontalCenter: parent.horizontalCenter
            text: toggle.modelData.label
            visible: toggleHover.hovered
            color: root.notch.inkDim
            font.family: root.notch.fontFamily
            font.pixelSize: root.notch.captionSize - 1
            textFormat: Text.PlainText
          }
        }
      }
    }
  }
}

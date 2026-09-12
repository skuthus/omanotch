import QtQuick

// What hovering shows when nothing is playing. Laid out on the card's
// insets: date and battery on the ears share the same edges as the clock
// and the controls below them; the clock is the one large element.
Item {
  id: root

  property var notch: null

  readonly property int strip: notch ? notch.notchHeight : 32
  readonly property int inset: notch ? notch.inset : 16

  property date now: new Date()
  Timer {
    interval: 1000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  // Leading ear: the date, on the left inset.
  Text {
    x: root.inset
    y: Math.round((root.strip - height) / 2)
    text: Qt.formatDate(root.now, "ddd d MMM")
    color: root.notch.inkDim
    font.family: root.notch.fontFamily
    font.pixelSize: root.notch.captionSize
    font.weight: Font.Medium
    textFormat: Text.PlainText
  }

  // Trailing ear: battery, on the right inset.
  Row {
    anchors.right: parent.right
    anchors.rightMargin: root.inset
    y: Math.round((root.strip - height) / 2)
    spacing: 4
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
      font.weight: Font.Medium
      font.features: { "tnum": 1 }
      textFormat: Text.PlainText
    }
  }

  Item {
    id: body
    x: root.inset
    y: root.strip
    width: root.width - root.inset * 2
    height: root.height - root.strip - Math.round(root.inset * 0.75)

    // One row, evenly spaced across the card: dials, reminder (and the
    // clock when enabled), toggles.
    Row {
      id: controls
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      readonly property int items: 9 + (clock.visible ? 1 : 0)
      readonly property real fixedWidth: 9 * root.notch.toggleSize + (clock.visible ? clock.width : 0)
      spacing: Math.max(6, Math.floor((body.width - fixedWidth) / (items - 1)))

      Repeater {
        model: root.notch.dials
        LevelDial {
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          notch: root.notch
          icon: modelData.icon
          level: modelData.level
          active: modelData.active
          onAdjust: function(delta) { root.notch.adjustDial(modelData.key, delta) }
          onTapped: root.notch.tapDial(modelData.key)
        }
      }

      Item {
        id: clock
        visible: root.notch.settings.showClock
        readonly property var parts: root.notch.clockParts(root.now)
        anchors.verticalCenter: parent.verticalCenter
        width: face.width
        height: face.height
        Row {
          id: face
          spacing: 5
          Text {
            id: digits
            text: clock.parts.time
            color: clockTap.pressed ? root.notch.accent : root.notch.ink
            font.family: root.notch.fontFamily
            font.pixelSize: root.notch.displaySize + 4
            font.weight: Font.DemiBold
            font.letterSpacing: -1
            font.features: { "tnum": 1 }
            textFormat: Text.PlainText
          }
          Text {
            y: digits.y + digits.baselineOffset - baselineOffset
            visible: text !== ""
            text: clock.parts.suffix
            color: root.notch.inkDim
            font.family: root.notch.fontFamily
            font.pixelSize: root.notch.captionSize + 1
            font.weight: Font.DemiBold
            textFormat: Text.PlainText
          }
        }
        MouseArea {
          id: clockTap
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.notch.toggleClockFormat()
        }
      }

      Rectangle {
        id: reminder
        anchors.verticalCenter: parent.verticalCenter
        width: root.notch.toggleSize
        height: width
        radius: width / 2
        color: root.notch.reminderPending ? root.notch.accent : (reminderHover.containsMouse ? root.notch.trackHover : root.notch.track)
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
          anchors.centerIn: parent
          text: "󰢌"
          color: root.notch.reminderPending ? root.notch.islandColor : root.notch.ink
          font.family: root.notch.fontFamily
          font.pixelSize: root.notch.iconSize - 2
          textFormat: Text.PlainText
        }
        MouseArea {
          id: reminderHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.notch.runToggle("reminder")
        }
      }

      Repeater {
        model: root.notch.toggles
        Rectangle {
          id: toggle
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          width: root.notch.toggleSize
          height: root.notch.toggleSize
          radius: width / 2
          color: modelData.active ? root.notch.accent : (toggleHover.containsMouse ? root.notch.trackHover : root.notch.track)
          Behavior on color { ColorAnimation { duration: 120 } }
          Text {
            anchors.centerIn: parent
            text: toggle.modelData.icon
            color: toggle.modelData.active ? root.notch.islandColor : root.notch.ink
            font.family: root.notch.fontFamily
            font.pixelSize: root.notch.iconSize - 2
            textFormat: Text.PlainText
          }
          MouseArea {
            id: toggleHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.notch.runToggle(toggle.modelData.key)
          }
        }
      }
    }
  }
}

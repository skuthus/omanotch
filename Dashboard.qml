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

    // Leading: level dials, mirroring the toggles on the trailing side.
    Row {
      id: leading
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8
      Repeater {
        model: root.notch.dials
        LevelDial {
          required property var modelData
          notch: root.notch
          icon: modelData.icon
          level: modelData.level
          active: modelData.active
          onAdjust: function(delta) { root.notch.adjustDial(modelData.key, delta) }
          onTapped: root.notch.tapDial(modelData.key)
        }
      }
    }

    // The clock: the one large element, centred under the notch. Click to
    // switch 12/24 hour.
    Item {
      id: clock
      readonly property var parts: root.notch.clockParts(root.now)
      anchors.horizontalCenter: parent.horizontalCenter
      // Bottom of the digits' ink sits on the bottom of the toggle row.
      y: trailing.y + trailing.height - height + Math.round((height - digits.baselineOffset) * 0.55)
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

    // Trailing: the Control Center style toggles.
    Item {
      id: trailing
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: toggleRow.width
      height: toggleRow.height

      Row {
        id: toggleRow
        spacing: 8

        Repeater {
          model: root.notch.toggles
          Rectangle {
            id: toggle
            required property var modelData
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
}

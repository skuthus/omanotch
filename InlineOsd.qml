import QtQuick

// An OSD that lands while the card is open: drawn in the right ear beside
// the notch, over whatever the card keeps there, so the card stays put.
Item {
  id: root

  property var notch: null
  property var event: null

  readonly property bool progress: event ? event.hasProgress === true : false
  readonly property int inner: Math.max(0, width - notch.pad)

  Rectangle {
    anchors.fill: parent
    color: root.notch.islandColor
  }

  Row {
    anchors.centerIn: parent
    spacing: root.notch.gap / 2

    Text {
      id: icon
      anchors.verticalCenter: parent.verticalCenter
      text: root.event ? String(root.event.icon || "") : ""
      color: root.notch.ink
      font.family: root.notch.fontFamily
      font.pixelSize: root.notch.bodySize + 2
      textFormat: Text.PlainText
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.progress
      width: Math.max(16, root.inner - icon.width - percent.width - parent.spacing * 2)
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
      id: percent
      anchors.verticalCenter: parent.verticalCenter
      text: root.event ? String(root.event.message || "") : ""
      color: root.notch.ink
      font.family: root.notch.fontFamily
      font.pixelSize: root.notch.captionSize
      font.bold: true
      horizontalAlignment: root.progress ? Text.AlignRight : Text.AlignLeft
      width: root.progress ? root.notch.percentWidth : Math.min(implicitWidth, root.inner - icon.width - parent.spacing)
      elide: Text.ElideRight
      maximumLineCount: 1
      textFormat: Text.PlainText
    }
  }
}

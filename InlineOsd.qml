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
    spacing: root.notch.gap

    LevelRing {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.progress
      width: Math.round(root.height * 0.68)
      height: width
      notch: root.notch
      icon: root.event ? String(root.event.icon || "") : ""
      level: root.progress ? root.event.value / root.event.max : 0
      active: !(root.event && root.event.iconKey && root.event.iconKey.indexOf("mute") !== -1)
      glyphSize: root.notch.captionSize
      stroke: 2
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.progress
      text: root.event ? String(root.event.icon || "") : ""
      color: root.notch.ink
      font.family: root.notch.fontFamily
      font.pixelSize: root.notch.bodySize + 2
      textFormat: Text.PlainText
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.event ? String(root.event.message || "") : ""
      color: root.notch.ink
      font.family: root.notch.fontFamily
      font.pixelSize: root.notch.captionSize
      font.weight: Font.DemiBold
      font.features: { "tnum": 1 }
      width: Math.min(implicitWidth, root.inner - root.notch.gap - Math.round(root.height * 0.68))
      elide: Text.ElideRight
      maximumLineCount: 1
      textFormat: Text.PlainText
    }
  }
}

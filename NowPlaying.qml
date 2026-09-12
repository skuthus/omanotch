import QtQuick

// The expanded now-playing card, composed like the macOS media widget: art
// on the leading inset, title and artist beside it, transport controls on
// the trailing inset, and a full-width progress bar underneath.
Item {
  id: root

  property var notch: null

  readonly property int strip: notch ? notch.notchHeight : 32
  readonly property int inset: notch ? notch.inset : 16
  readonly property var player: notch ? notch.player : null
  readonly property bool playing: player ? player.isPlaying === true : false
  readonly property real position: player && player.positionSupported ? Number(player.position) || 0 : 0
  readonly property real length: player && player.lengthSupported ? Number(player.length) || 0 : 0
  readonly property bool canSeek: player ? player.canSeek === true && root.length > 0 : false

  // Leading ear: which app is playing, quietly.
  Text {
    x: root.inset
    y: Math.round((root.strip - height) / 2)
    text: root.notch.appLabel
    color: root.notch.inkDim
    font.family: root.notch.fontFamily
    font.pixelSize: root.notch.captionSize
    font.weight: Font.Medium
    elide: Text.ElideRight
    maximumLineCount: 1
    width: Math.min(implicitWidth, root.width / 2 - root.inset)
    textFormat: Text.PlainText
  }

  // Trailing ear: the visualizer.
  Visualizer {
    anchors.right: parent.right
    anchors.rightMargin: root.inset
    y: Math.round((root.strip - height) / 2)
    height: Math.round(root.strip * 0.5)
    bars: root.notch.visualizerBars
    levels: root.notch.levels
    color: root.notch.accent
    barWidth: 3
    gap: 3
  }

  Item {
    id: body
    x: root.inset
    y: root.strip + Math.round(root.inset * 0.5)
    width: root.width - root.inset * 2
    height: root.height - y - Math.round(root.inset * 0.75)

    readonly property int artSize: Math.round(root.strip * 1.6)

    RoundedImage {
      id: art
      x: 0
      y: 0
      width: body.artSize
      height: body.artSize
      radius: Math.round(body.artSize * 0.18)
      source: root.notch.artUrl
      placeholderColor: root.notch.artPlaceholder
      glyphColor: root.notch.artGlyph
      fontFamily: root.notch.fontFamily
      glyphSize: root.notch.iconSize
    }

    // Transport controls on the trailing edge, centred on the art.
    Row {
      id: controls
      anchors.right: parent.right
      anchors.verticalCenter: art.verticalCenter
      spacing: 14

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.notch.sourceCount > 1
        text: "󰒝"
        color: sourceTap.pressed ? root.notch.ink : root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.iconSize - 2
        textFormat: Text.PlainText
        MouseArea { id: sourceTap; anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.notch.switchSource() }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰒮"
        opacity: root.player && root.player.canGoPrevious ? 1 : 0.3
        color: prevTap.pressed ? root.notch.inkDim : root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.iconSize + 2
        textFormat: Text.PlainText
        MouseArea { id: prevTap; anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player && root.player.canGoPrevious) root.player.previous() }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.playing ? "󰏤" : "󰐊"
        opacity: root.player && root.player.canTogglePlaying ? 1 : 0.3
        color: playTap.pressed ? root.notch.inkDim : root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.iconSize + 10
        textFormat: Text.PlainText
        MouseArea { id: playTap; anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying() }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰒭"
        opacity: root.player && root.player.canGoNext ? 1 : 0.3
        color: nextTap.pressed ? root.notch.inkDim : root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.iconSize + 2
        textFormat: Text.PlainText
        MouseArea { id: nextTap; anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player && root.player.canGoNext) root.player.next() }
      }
    }

    // Title and artist between art and controls.
    Column {
      anchors.left: art.right
      anchors.leftMargin: 12
      anchors.right: controls.left
      anchors.rightMargin: 12
      anchors.verticalCenter: art.verticalCenter
      spacing: 1
      Text {
        width: parent.width
        text: root.notch.title !== "" ? root.notch.title : "Nothing playing"
        color: root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.bodySize + 1
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        maximumLineCount: 1
        textFormat: Text.PlainText
      }
      Text {
        width: parent.width
        visible: text !== ""
        text: root.notch.subtitle
        color: root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.captionSize
        elide: Text.ElideRight
        maximumLineCount: 1
        textFormat: Text.PlainText
      }
    }

    // Full-width progress with elapsed and remaining underneath.
    Item {
      id: seek
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: track.height + 4 + elapsed.height
      visible: root.length > 0

      Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.notch.trackHeight
        radius: height / 2
        color: root.notch.track
        Rectangle {
          height: parent.height
          radius: parent.radius
          width: parent.width * root.notch.progressFraction(root.position, root.length)
          color: root.notch.ink
          Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        MouseArea {
          anchors.fill: parent
          anchors.topMargin: -8
          anchors.bottomMargin: -8
          enabled: root.canSeek
          cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: function(mouse) {
            if (!root.player) return
            var fraction = Math.max(0, Math.min(1, mouse.x / track.width))
            root.player.position = fraction * root.length
          }
        }
      }
      Text {
        id: elapsed
        anchors.left: parent.left
        anchors.top: track.bottom
        anchors.topMargin: 4
        text: root.notch.formatClock(root.position)
        color: root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.captionSize - 1
        font.features: { "tnum": 1 }
        textFormat: Text.PlainText
      }
      Text {
        anchors.right: parent.right
        anchors.top: track.bottom
        anchors.topMargin: 4
        text: "-" + root.notch.formatClock(Math.max(0, root.length - root.position))
        color: root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.captionSize - 1
        font.features: { "tnum": 1 }
        textFormat: Text.PlainText
      }
    }
  }
}

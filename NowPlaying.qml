import QtQuick

// The expanded now-playing card: source name and visualizer on the ears,
// art, titles, seek bar and transport controls below the notch.
Item {
  id: root

  property var notch: null

  readonly property real earWidth: Math.max(0, (width - (notch ? notch.notchWidth : 0)) / 2)
  readonly property int strip: notch ? notch.notchHeight : 32
  readonly property var player: notch ? notch.player : null
  readonly property bool playing: player ? player.isPlaying === true : false
  readonly property real position: player && player.positionSupported ? Number(player.position) || 0 : 0
  readonly property real length: player && player.lengthSupported ? Number(player.length) || 0 : 0
  readonly property bool canSeek: player ? player.canSeek === true && root.length > 0 : false
  readonly property int artSize: Math.round((height - strip) - notch.pad * 2)

  // Left ear: which app is playing.
  Item {
    x: 0
    width: root.earWidth
    height: root.strip
    Row {
      anchors.centerIn: parent
      spacing: root.notch.gap / 2
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰝚"
        color: root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.captionSize
        textFormat: Text.PlainText
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.notch.appLabel
        color: root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.captionSize
        elide: Text.ElideRight
        maximumLineCount: 1
        width: Math.min(implicitWidth, root.earWidth - root.notch.pad * 2 - 16)
        textFormat: Text.PlainText
      }
    }
  }

  // Right ear: the visualizer.
  Visualizer {
    x: root.width - root.earWidth + Math.round((root.earWidth - width) / 2)
    y: Math.round((root.strip - height) / 2)
    height: Math.round(root.strip * 0.55)
    bars: root.notch.visualizerBars
    levels: root.notch.levels
    color: root.notch.accent
    barWidth: 3
    gap: 3
  }

  RoundedImage {
    id: art
    x: root.notch.pad
    y: root.strip + root.notch.pad
    width: root.artSize
    height: root.artSize
    radius: Math.round(root.artSize * 0.16)
    source: root.notch.artUrl
    placeholderColor: root.notch.artPlaceholder
    glyphColor: root.notch.artGlyph
    fontFamily: root.notch.fontFamily
    glyphSize: root.notch.iconSize * 1.4
  }

  Item {
    id: body
    x: art.x + art.width + root.notch.pad
    y: root.strip + root.notch.pad
    width: root.width - x - root.notch.pad
    height: root.artSize

    Column {
      id: titles
      width: parent.width
      spacing: 0
      Text {
        width: parent.width
        text: root.notch.title !== "" ? root.notch.title : "Nothing playing"
        color: root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.bodySize
        font.bold: true
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

    // Seek bar with elapsed and total time.
    Item {
      id: seek
      y: Math.round((titles.height + controls.y - height) / 2)
      width: parent.width
      height: Math.max(root.notch.trackHeight, 10)
      visible: root.length > 0

      Text {
        id: elapsed
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.notch.formatClock(root.position)
        color: root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.captionSize
        textFormat: Text.PlainText
      }
      Text {
        id: total
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.notch.formatClock(root.length)
        color: root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.captionSize
        textFormat: Text.PlainText
      }
      Rectangle {
        id: track
        anchors.left: elapsed.right
        anchors.right: total.left
        anchors.leftMargin: root.notch.gap
        anchors.rightMargin: root.notch.gap
        anchors.verticalCenter: parent.verticalCenter
        height: root.notch.trackHeight
        radius: height / 2
        color: root.notch.track
        Rectangle {
          height: parent.height
          radius: parent.radius
          width: parent.width * root.notch.progressFraction(root.position, root.length)
          color: root.notch.accent
          Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        MouseArea {
          anchors.fill: parent
          anchors.topMargin: -6
          anchors.bottomMargin: -6
          enabled: root.canSeek
          cursorShape: root.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: function(mouse) {
            if (!root.player) return
            var fraction = Math.max(0, Math.min(1, mouse.x / track.width))
            root.player.position = fraction * root.length
          }
        }
      }
    }

    Row {
      id: controls
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: root.notch.pad

      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.notch.sourceCount > 1
        text: "󰒝"
        color: sourceTap.pressed ? root.notch.ink : root.notch.inkDim
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.iconSize
        textFormat: Text.PlainText
        MouseArea { id: sourceTap; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.notch.switchSource() }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰒮"
        opacity: root.player && root.player.canGoPrevious ? 1 : 0.35
        color: prevTap.pressed ? root.notch.accent : root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.iconSize * 1.15
        textFormat: Text.PlainText
        MouseArea { id: prevTap; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player && root.player.canGoPrevious) root.player.previous() }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.playing ? "󰏤" : "󰐊"
        opacity: root.player && root.player.canTogglePlaying ? 1 : 0.35
        color: playTap.pressed ? root.notch.accent : root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.iconSize * 1.6
        textFormat: Text.PlainText
        MouseArea { id: playTap; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying() }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰒭"
        opacity: root.player && root.player.canGoNext ? 1 : 0.35
        color: nextTap.pressed ? root.notch.accent : root.notch.ink
        font.family: root.notch.fontFamily
        font.pixelSize: root.notch.iconSize * 1.15
        textFormat: Text.PlainText
        MouseArea { id: nextTap; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player && root.player.canGoNext) root.player.next() }
      }
    }
  }
}

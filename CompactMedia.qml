import QtQuick

// The wings while music plays: album art on the left ear, the visualizer on
// the right, notch untouched in the middle.
Item {
  id: root

  property var notch: null

  readonly property real earWidth: Math.max(0, (width - (notch ? notch.notchWidth : 0)) / 2)
  readonly property int artSize: Math.round(height * 0.68)

  RoundedImage {
    x: Math.round((root.earWidth - width) / 2)
    anchors.verticalCenter: parent.verticalCenter
    width: root.artSize
    height: root.artSize
    radius: Math.round(root.artSize * 0.25)
    source: root.notch.artUrl
    fontFamily: root.notch.fontFamily
    glyphSize: root.notch.captionSize
  }

  Visualizer {
    x: root.width - root.earWidth + Math.round((root.earWidth - width) / 2)
    anchors.verticalCenter: parent.verticalCenter
    height: Math.round(root.height * 0.55)
    bars: root.notch.visualizerBars
    levels: root.notch.levels
    color: root.notch.accent
    barWidth: 3
    gap: 3
  }
}

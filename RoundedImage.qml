import QtQuick
import QtQuick.Effects

// An Image clipped to a rounded rectangle, with a glyph placeholder while
// there is nothing to show.
Item {
  id: root

  property string source: ""
  property real radius: 6
  property color placeholderColor: "#2a2a2e"
  property color glyphColor: "#9a9aa0"
  property string glyph: "󰝚"
  property string fontFamily: "monospace"
  property int glyphSize: 14

  readonly property bool ready: root.source !== "" && image.status === Image.Ready

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: root.placeholderColor
    visible: !root.ready
    Text {
      anchors.centerIn: parent
      text: root.glyph
      color: root.glyphColor
      font.family: root.fontFamily
      font.pixelSize: root.glyphSize
    }
  }

  Image {
    id: image
    anchors.fill: parent
    source: root.source
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
    cache: true
    smooth: true
    visible: false
    sourceSize.width: Math.max(1, Math.round(width * 2))
    sourceSize.height: Math.max(1, Math.round(height * 2))
  }

  Rectangle {
    id: mask
    anchors.fill: parent
    radius: root.radius
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    anchors.fill: image
    source: image
    visible: root.ready
    maskEnabled: true
    maskSource: mask
  }
}

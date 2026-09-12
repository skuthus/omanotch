import QtQuick
import Quickshell

// A notification preview: app icon and name on the ears beside the notch,
// summary and body across the full width below it.
Item {
  id: root

  property var notch: null
  property var event: null

  readonly property real earWidth: Math.max(0, (width - (notch ? notch.notchWidth : 0)) / 2)
  readonly property int strip: notch ? notch.notchHeight : 32
  readonly property string iconSource: {
    if (!root.event) return ""
    var image = String(root.event.image || "")
    if (image !== "") return image.indexOf("/") === 0 ? "file://" + image : image
    var name = String(root.event.appIcon || "")
    if (name === "") return ""
    if (name.indexOf("/") === 0) return "file://" + name
    if (name.indexOf("file://") === 0) return name
    var resolved = Quickshell.iconPath(name, true)
    return resolved ? resolved : ""
  }

  // Left ear: the app icon.
  Item {
    x: 0
    width: root.earWidth
    height: root.strip
    Image {
      id: appIcon
      anchors.centerIn: parent
      width: Math.round(root.strip * 0.62)
      height: width
      source: root.iconSource
      sourceSize.width: width * 2
      sourceSize.height: height * 2
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      visible: status === Image.Ready
    }
    Text {
      anchors.centerIn: parent
      visible: appIcon.status !== Image.Ready
      text: root.event && root.event.glyph ? String(root.event.glyph) : "󰂚"
      color: root.notch.ink
      font.family: root.notch.fontFamily
      font.pixelSize: root.notch.iconSize
      textFormat: Text.PlainText
    }
  }

  // Right ear: the app name.
  Item {
    x: root.width - width
    width: root.earWidth
    height: root.strip
    Text {
      anchors.centerIn: parent
      width: root.earWidth - root.notch.pad * 2
      horizontalAlignment: Text.AlignHCenter
      text: root.event ? String(root.event.app || "") : ""
      color: root.notch.inkDim
      font.family: root.notch.fontFamily
      font.pixelSize: root.notch.captionSize
      elide: Text.ElideRight
      maximumLineCount: 1
      textFormat: Text.PlainText
    }
  }

  Column {
    x: root.notch.pad
    y: root.strip + root.notch.gap / 2
    width: root.width - root.notch.pad * 2
    spacing: 1
    Text {
      width: parent.width
      text: root.event ? String(root.event.title || "") : ""
      color: root.event && root.event.urgent ? root.notch.urgentInk : root.notch.ink
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
      text: root.event ? String(root.event.message || "") : ""
      color: root.notch.inkDim
      font.family: root.notch.fontFamily
      font.pixelSize: root.notch.captionSize
      elide: Text.ElideRight
      maximumLineCount: 1
      textFormat: Text.PlainText
    }
  }
}

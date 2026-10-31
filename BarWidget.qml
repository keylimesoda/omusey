import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Bar entry: your Muse avatar. Click → bin/muse-toggle drops the muse.ai web
// app down from the bar (Hyprland special workspace "muse"). While it is down,
// a small tab hangs off its bottom-right corner to pop it out into a window.
BarWidget {
  id: root
  moduleName: "telep.muse"

  // Dropdown geometry, monitor-local. Handed to bin/muse-toggle on every click.
  readonly property int dropWidth: Number(setting("width", 480))
  readonly property int dropHeight: Math.round((screen ? screen.height : 1200) * Number(setting("heightPercent", 60)) / 100)
  readonly property int dropTop: (bar && bar.position === "top" ? barSize : 0) + Style.space(8)
  readonly property string avatar: String(setting("avatar", ""))

  // Default-mark color. "theme" follows the bar's own foreground (how the
  // rest of the bar paints), "accent"/"urgent" follow those theme roles, a
  // hex or CSS color pins it (brand blue by default). Invalid values fall
  // back to the brand blue; ignored when an avatar image is set.
  function resolveIconColor() {
    var c = String(setting("iconColor", "#0079f3")).trim().toLowerCase()
    if (c === "" || c === "theme" || c === "foreground") return root.bar ? root.bar.barForeground : Color.foreground
    if (c === "accent") return Color.accent
    if (c === "urgent") return root.bar ? root.bar.urgent : Color.urgent
    if (/^#?([0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8})$/.test(c) || /^[a-z]+$/.test(c)) return c
    return "#0079f3"
  }
  readonly property color iconColor: resolveIconColor()

  readonly property var screen: QsWindow.window ? QsWindow.window.screen : null
  readonly property string toggleBin: Qt.resolvedUrl("bin/muse-toggle").toString().replace("file://", "")
  property bool dropped: false
  property int centerX: 0

  function toggle() {
    centerX = Math.round(button.mapToItem(null, button.width / 2, 0).x)
    Quickshell.execDetached([toggleBin, String(centerX), String(dropTop), String(dropWidth), String(dropHeight)])
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "activespecial") return
      var parts = event.data.split(",")
      if (root.screen && parts[1] === root.screen.name) root.dropped = parts[0] === "special:muse"
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    fixedWidth: icon.width + 2 * scaledHorizontalMargin
    hasVisualContent: true
    tooltipText: "Muse"
    onPressed: root.toggle()

    // The Muse mark is painted flat from its bundled PNG used as an alpha
    // mask, in the color resolved from the iconColor setting (brand blue
    // #0079f3 by default; "theme" makes it follow the bar foreground like
    // other bar icons). A user-set avatar keeps its own pixels.
    Image {
      id: icon
      anchors.centerIn: parent
      width: Math.round(button.barSize * 0.75)
      height: width
      smooth: true
      mipmap: true
      source: root.avatar !== "" ? "file://" + root.avatar.replace(/^~/, Quickshell.env("HOME")) : Qt.resolvedUrl("muse.png")
      visible: root.avatar !== ""
      layer.enabled: root.avatar === ""
    }

    ColorOverlay {
      anchors.fill: icon
      visible: root.avatar === ""
      source: icon
      color: root.iconColor
    }
  }

  PanelWindow {
    id: popTab
    visible: root.dropped && root.screen !== null
    screen: root.screen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "telep-muse-popout"
    anchors { top: true; left: true }
    implicitWidth: tabLabel.implicitWidth + Style.space(20)
    implicitHeight: tabLabel.implicitHeight + Style.space(10)
    margins {
      left: Math.max(0, Math.min((root.screen ? root.screen.width : 0) - root.dropWidth, root.centerX - root.dropWidth / 2)) + root.dropWidth - implicitWidth
      top: root.dropTop + root.dropHeight + Style.space(4)
    }

    Rectangle {
      anchors.fill: parent
      radius: Style.space(6)
      color: root.bar ? root.bar.background : Color.background
      border.width: 1
      border.color: Qt.darker(tabLabel.color, 2)

      Text {
        id: tabLabel
        anchors.centerIn: parent
        text: "󰏋  pop out"
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached([root.toggleBin, "popout"])
      }
    }
  }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import qs.Commons
import "NotchModel.js" as Model

// Omanotch: the MacBook notch as a Dynamic Island. This file owns the
// layer-shell window, the island state machine and event queue, the OSD
// takeover, and every watcher that feeds the island. The views are
// separate files that read what they need off `notch`.
Item {
  id: root

  // Injected by the shell's panel loader.
  property var shell: null
  property var manifest: null

  readonly property string pluginId: manifest && manifest.id ? String(manifest.id) : "skuthus.omanotch"

  // ------------------------------------------------------------ settings

  readonly property var settingsEntry: Model.pluginEntry(shell ? shell.shellConfig : null, pluginId)
  readonly property var settings: Model.resolveSettings(settingsEntry)

  function setSetting(key, value) {
    if (!shell || typeof shell.mutateShellConfig !== "function") return
    var patch = {}
    patch[key] = value
    shell.mutateShellConfig(Model.settingsMutator(pluginId, patch))
  }

  function clockParts(date) { return Model.clockParts(date.getHours(), date.getMinutes(), settings.clock24) }
  function toggleClockFormat() { setSetting("clock24", !settings.clock24) }

  property bool calibrating: false
  property int calWidth: 0
  property int calHeight: 0
  readonly property int notchWidth: calibrating ? calWidth : settings.notchWidth
  readonly property int notchHeight: calibrating ? calHeight : settings.notchHeight

  // ------------------------------------------------------------- theming

  // The island stays black so it blends into the camera cutout, but the ink
  // and accent follow the theme the way the shell's popups do. A
  // theme can steer them directly from an [omanotch] section in shell.toml;
  // otherwise text comes from the popup text colour when it reads on black
  // and the accent from the theme accent (lifted if it would sink).
  readonly property string fontFamily: Style.font.family
  readonly property int captionSize: Style.font.caption
  readonly property int bodySize: Style.font.body
  readonly property int iconSize: Style.font.iconLarge
  readonly property int displaySize: Style.font.display
  readonly property int pad: Style.space(10)
  readonly property int gap: Style.space(8)
  // Content inset of the expanded card; leading and trailing items share it.
  readonly property int inset: Style.space(16)
  readonly property int trackHeight: Math.max(3, Style.space(4))
  readonly property int toggleSize: Style.space(28)

  function luminance(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b }
  function legibleOnIsland(c, fallback) { return luminance(c) >= 0.55 ? c : fallback }
  function liftedOnIsland(c) { return luminance(c) < 0.4 ? Qt.lighter(c, 1.9) : c }

  readonly property color islandColor: Color.pick("omanotch.background", "#000000")
  readonly property color ink: legibleOnIsland(Color.pick("omanotch.text", Color.popups.text), "#f4f4f5")
  readonly property color inkDim: Qt.rgba(ink.r, ink.g, ink.b, 0.58)
  readonly property color track: Qt.rgba(ink.r, ink.g, ink.b, 0.14)
  readonly property color trackHover: Qt.rgba(ink.r, ink.g, ink.b, 0.22)
  readonly property color urgentInk: liftedOnIsland(Color.pick("omanotch.urgent", Color.urgent))
  readonly property color accent: liftedOnIsland(Color.pick("omanotch.accent", Color.accent))
  readonly property color accentFill: Qt.rgba(accent.r, accent.g, accent.b, 0.22)
  readonly property color artPlaceholder: Qt.rgba(accent.r, accent.g, accent.b, 0.16)
  readonly property color artGlyph: Qt.rgba(accent.r, accent.g, accent.b, 0.8)
  readonly property int percentWidth: Math.ceil(percentMetrics.advanceWidth)

  TextMetrics {
    id: percentMetrics
    font.family: root.fontFamily
    font.pixelSize: root.bodySize
    font.bold: true
    text: "100%"
  }

  // ------------------------------------------------------------ services

  // Services mount alongside panels, so poll until each one answers.
  property var media: null
  property var notifications: null
  property var nightlight: null
  property var idle: null

  function resolveServices() {
    if (!shell || typeof shell.serviceFor !== "function") return
    if (!media) media = shell.serviceFor("omarchy.media")
    if (!notifications) notifications = shell.serviceFor("omarchy.notifications")
    if (!nightlight) nightlight = shell.serviceFor("omarchy.nightlight")
    if (!idle) idle = shell.serviceFor("omarchy.idle")
  }

  onShellChanged: resolveServices()
  Timer {
    interval: 750
    repeat: true
    running: !root.media || !root.notifications || !root.nightlight || !root.idle
    onTriggered: root.resolveServices()
  }

  // Watchers that react to changes should not fire for the values they
  // first read at startup.
  property bool settled: false
  Timer { interval: 3000; running: true; onTriggered: root.settled = true }

  // --------------------------------------------------------------- media

  readonly property var player: media ? media.activePlayer : null
  readonly property bool hasMedia: media ? media.hasMedia === true : false
  readonly property bool mediaPlaying: player ? player.isPlaying === true : false
  readonly property string title: media ? String(media.title || "") : ""
  readonly property string artist: media ? String(media.artist || "") : ""
  readonly property string album: media ? String(media.album || "") : ""
  readonly property string artUrl: media ? String(media.artUrl || "") : ""
  readonly property string appLabel: media && player ? String(media.playerAppLabel(player) || media.identity || "") : ""
  readonly property string subtitle: Model.mediaSubtitle(artist, album, appLabel)
  readonly property int sourceCount: media && media.sourceCyclePlayers ? media.sourceCyclePlayers.length : 0

  function switchSource() {
    if (media && typeof media.switchSource === "function") media.switchSource(1, false, false)
  }

  function formatClock(seconds) { return Model.formatClock(seconds) }
  function progressFraction(position, length) { return Model.progressFraction(position, length) }

  // Mpris positions only refresh on request.
  Timer {
    interval: 1000
    repeat: true
    running: root.expanded && root.player !== null && root.mediaPlaying
    triggeredOnStart: true
    onTriggered: if (root.player && root.player.positionSupported) root.player.positionChanged()
  }

  // ------------------------------------------------------------ visualizer

  readonly property int visualizerBars: 4
  property var levels: []
  property bool cavaAvailable: false
  readonly property string visualizerMode: Model.visualizerMode(settings.visualizer, cavaAvailable)
  readonly property bool wantLevels: mediaPlaying && visualizerMode !== "off"
    && (islandState === "compact" || islandState === "expanded")

  Process {
    id: cavaProbe
    command: ["sh", "-c", "command -v cava >/dev/null 2>&1"]
    running: true
    onExited: function(code) { root.cavaAvailable = code === 0 }
  }

  // The config rides in as a process substitution, so nothing is written
  // to disk and cava starts the moment it is wanted.
  Process {
    id: cava
    command: ["bash", "-c", "exec cava -p <(printf '%s' \"$1\")", "_", Model.cavaConfig(root.visualizerBars, 30)]
    running: root.wantLevels && root.visualizerMode === "cava"
    stdout: SplitParser {
      onRead: function(line) { root.levels = Model.parseCavaLine(line, root.visualizerBars, 100) }
    }
    onExited: root.levels = []
  }

  Timer {
    interval: 50
    repeat: true
    running: root.wantLevels && root.visualizerMode === "fake"
    onTriggered: root.levels = Model.fakeBars(Date.now() / 1000, root.visualizerBars)
  }
  onWantLevelsChanged: if (!wantLevels) levels = []

  // ------------------------------------------------------------- battery

  // The device state is the source of truth: it distinguishes charging from
  // plugged-in-but-holding and from full, and UPower's onBattery flag lags
  // it at startup. (Do not name a property onBattery: QML reads the "on"
  // prefix as a signal handler and the binding silently misbehaves.)
  readonly property var battery: UPower.displayDevice
  readonly property int batteryState: battery ? Number(battery.state) : UPowerDeviceState.Unknown
  readonly property bool batteryPresent: battery ? battery.isPresent === true : false
  readonly property int batteryPercent: batteryPresent ? Math.round(Number(battery.percentage || 0) * 100) : -1
  readonly property bool batteryCharging: batteryState === UPowerDeviceState.Charging
  readonly property bool usingBattery: {
    if (batteryState === UPowerDeviceState.Discharging) return true
    if (batteryState === UPowerDeviceState.Charging
        || batteryState === UPowerDeviceState.PendingCharge
        || batteryState === UPowerDeviceState.FullyCharged) return false
    return UPower.onBattery === true
  }
  readonly property bool batteryLow: batteryPercent >= 0 && batteryPercent <= 20 && usingBattery
  readonly property string batteryIcon: batteryPercent >= 0 ? Model.batteryIcon(batteryPercent, !usingBattery) : ""
  readonly property string batteryDetail: {
    if (!batteryPresent) return ""
    if (batteryState === UPowerDeviceState.Charging) {
      var full = Model.formatDuration(battery.timeToFull)
      return full ? full + " until full" : "Charging"
    }
    if (batteryState === UPowerDeviceState.PendingCharge) return "Plugged in, not charging"
    if (batteryState === UPowerDeviceState.FullyCharged) return "Fully charged"
    if (batteryState === UPowerDeviceState.Discharging) {
      var left = Model.formatDuration(battery.timeToEmpty)
      return left ? left + " remaining" : "On battery"
    }
    return usingBattery ? "On battery" : "Plugged in"
  }
  property var lowWarned: []

  function checkLowBattery() {
    if (!settings.batteryEvents || batteryPercent < 0) return
    var r = Model.lowBatteryCheck(batteryPercent, usingBattery, settings.lowBatteryLevels, lowWarned)
    lowWarned = r.warned
    if (r.event && settled) pushEvent(r.event)
  }

  onUsingBatteryChanged: {
    if (!settled || !settings.batteryEvents || batteryPercent < 0) return
    var seconds = usingBattery ? battery.timeToEmpty : battery.timeToFull
    pushEvent(Model.powerSourceEvent(usingBattery, batteryPercent, seconds, settings.eventDuration))
    checkLowBattery()
  }
  onBatteryPercentChanged: checkLowBattery()

  // ------------------------------------------------------------- airpods

  property bool airpodsConnected: false
  readonly property string airpodsStatePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/librepods/status.json"

  FileView {
    id: airpodsFile
    path: root.airpodsStatePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.applyAirpods(text())
    onLoadFailed: root.airpodsConnected = false
  }

  function applyAirpods(raw) {
    var status = Model.parseAirpods(raw)
    var connected = status ? status.connected : false
    var was = airpodsConnected
    airpodsConnected = connected
    if (connected && !was && settled && settings.airpods) {
      var ev = Model.airpodsEvent(status, settings.eventDuration)
      if (ev) pushEvent(ev)
    }
  }

  // -------------------------------------------------------- notifications

  Connections {
    target: root.notifications ? root.notifications.popupModel : null
    ignoreUnknownSignals: true
    function onRowsInserted(parent, first, last) {
      if (!root.settings.notifications || !root.settled) return
      for (var i = first; i <= last; i++) {
        var row = root.notifications.popupModel.get(i)
        if (!row) continue
        root.pushEvent(Model.notificationEvent(row, root.settings.notificationDuration))
      }
    }
  }

  // --------------------------------------------------------- status flashes

  function flash(key, on, detail) {
    if (!settled || !settings.statusFlashes) return
    var ev = Model.flashEvent(key, on, detail)
    if (ev) pushEvent(ev)
  }

  // Caps Lock: the keyboard LED in sysfs is the only signal Hyprland leaves us.
  property string capsPath: ""
  property bool capsOn: false
  property bool capsRead: false
  Process {
    command: ["sh", "-c", "ls -d /sys/class/leds/*capslock 2>/dev/null | head -n1"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.capsPath = String(this.text || "").trim() }
  }
  FileView {
    id: capsFile
    path: root.capsPath + "/brightness"
    printErrors: false
    onLoaded: {
      var on = String(text() || "").trim() !== "0"
      if (root.capsRead && on !== root.capsOn) root.flash("capslock", on)
      root.capsOn = on
      root.capsRead = true
    }
  }
  Timer {
    interval: 250
    repeat: true
    running: root.capsPath !== ""
    onTriggered: capsFile.reload()
  }

  // Microphone mute, from wherever it was toggled. Scripts also send an OSD
  // for it, so a flash right after that OSD is dropped.
  readonly property var micNode: Pipewire.defaultAudioSource
  PwObjectTracker { objects: root.micNode ? [root.micNode] : [] }
  readonly property bool micMuted: micNode && micNode.audio ? micNode.audio.muted === true : false
  property double lastMicOsdAt: 0
  onMicMutedChanged: {
    if (Date.now() - lastMicOsdAt < 1500) return
    flash("mic", !micMuted)
  }

  // Screen recording: the recorder is a separate process, so poll for it.
  property bool recording: false
  property bool recordingRead: false
  Process {
    id: recordingProbe
    command: ["sh", "-c", "pgrep -x 'gpu-screen-recorder|wf-recorder' >/dev/null 2>&1"]
    onExited: function(code) {
      var on = code === 0
      if (root.recordingRead && on !== root.recording) root.flash("recording", on)
      root.recording = on
      root.recordingRead = true
    }
  }
  Timer {
    interval: 3000
    repeat: true
    running: root.settings.statusFlashes
    triggeredOnStart: true
    onTriggered: if (!recordingProbe.running) recordingProbe.running = true
  }

  readonly property bool dnd: notifications ? notifications.doNotDisturb === true : false
  onDndChanged: flash("dnd", dnd)

  readonly property bool nightlightOn: nightlight ? nightlight.enabled === true : false
  onNightlightOnChanged: flash("nightlight", nightlightOn)

  readonly property bool stayAwake: idle ? idle.stayAwake === true : false
  onStayAwakeChanged: flash("stayawake", stayAwake)

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || String(event.name) !== "activelayout") return
      var name = Model.layoutFromEvent(event.data)
      if (name) root.flash("layout", true, name)
    }
  }

  // ------------------------------------------------------- level dials

  // Volume from PipeWire; display and keyboard backlight from sysfs, read
  // only while the dashboard is showing.
  readonly property var sinkNode: Pipewire.defaultAudioSink
  PwObjectTracker { objects: root.sinkNode ? [root.sinkNode] : [] }
  readonly property real volumeLevel: sinkNode && sinkNode.audio ? Number(sinkNode.audio.volume) || 0 : 0
  readonly property bool volumeMuted: sinkNode && sinkNode.audio ? sinkNode.audio.muted === true : false

  property string backlightPath: ""
  property real backlightMax: 0
  property real backlightLevel: 0
  Process {
    command: ["sh", "-c", "for d in /sys/class/backlight/*; do echo \"$d\"; cat \"$d/max_brightness\"; break; done"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        var lines = String(this.text || "").trim().split("\n")
        if (lines.length >= 2) { root.backlightPath = lines[0]; root.backlightMax = Number(lines[1]) || 0 }
      }
    }
  }
  FileView {
    id: backlightFile
    path: root.backlightPath ? root.backlightPath + "/brightness" : ""
    printErrors: false
    onLoaded: root.backlightLevel = root.backlightMax > 0 ? (Number(String(text()).trim()) || 0) / root.backlightMax : 0
  }

  readonly property string kbdPath: "/sys/class/leds/kbd_backlight"
  property real kbdMax: 0
  property real kbdLevel: 0
  FileView {
    path: root.kbdPath + "/max_brightness"
    printErrors: false
    onLoaded: root.kbdMax = Number(String(text()).trim()) || 0
  }
  FileView {
    id: kbdFile
    path: root.kbdPath + "/brightness"
    printErrors: false
    onLoaded: root.kbdLevel = root.kbdMax > 0 ? (Number(String(text()).trim()) || 0) / root.kbdMax : 0
  }
  readonly property bool dashboardShowing: islandState === "expanded" && expandedMode === "dashboard"
  Timer {
    interval: 400
    repeat: true
    running: root.dashboardShowing
    triggeredOnStart: true
    onTriggered: { if (root.backlightPath) backlightFile.reload(); kbdFile.reload() }
  }

  readonly property var dials: [
    { key: "volume", icon: volumeMuted ? "󰖁" : (volumeLevel < 0.34 ? "󰕿" : (volumeLevel < 0.67 ? "󰖀" : "󰕾")), level: volumeLevel, active: !volumeMuted },
    { key: "brightness", icon: "󰃟", level: backlightLevel, active: true },
    { key: "keyboard", icon: "󰌌", level: kbdLevel, active: kbdLevel > 0 }
  ]

  function adjustDial(key, delta) {
    if (key === "volume") Quickshell.execDetached(["omarchy-audio-output-volume", delta > 0 ? "raise" : "lower"])
    else if (key === "brightness") Quickshell.execDetached(["omarchy-brightness-display", delta > 0 ? "+5%" : "5%-"])
    else if (key === "keyboard") Quickshell.execDetached(["omarchy-brightness-keyboard", delta > 0 ? "up" : "down"])
  }

  function tapDial(key) {
    if (key === "volume") Quickshell.execDetached(["omarchy-audio-output-volume", "mute-toggle"])
    else if (key === "keyboard") Quickshell.execDetached(["omarchy-brightness-keyboard", "cycle"])
  }

  readonly property var toggles: [
    { key: "dnd", icon: dnd ? "󰂛" : "󰂚", label: "Do Not Disturb", active: dnd },
    { key: "nightlight", icon: "󰖔", label: "Night Light", active: nightlightOn },
    { key: "stayawake", icon: "󰅶", label: "Stay Awake", active: stayAwake }
  ]

  function runToggle(key) {
    if (key === "dnd" && notifications) notifications.setDoNotDisturb(!dnd)
    else if (key === "nightlight" && nightlight) nightlight.setNightlight(!nightlightOn)
    else if (key === "stayawake" && idle) idle.setIdleEnabled(stayAwake)
  }

  // ------------------------------------------------------ event queue

  property var currentEvent: null
  property var queue: []

  function pushEvent(ev) {
    if (!ev) return
    if (ev.kind === "osd" && Model.isMicIconKey(ev.iconKey)) lastMicOsdAt = Date.now()
    var r = Model.enqueue(currentEvent, queue, ev)
    queue = r.queue
    if (r.replaced) {
      currentEvent = r.current
      eventTimer.interval = Math.max(1, r.current.duration)
      eventTimer.restart()
    } else if (!currentEvent) {
      advance()
    }
  }

  function advance() {
    if (queue.length > 0) {
      var next = queue.slice()
      currentEvent = next.shift()
      queue = next
      eventTimer.interval = Math.max(1, currentEvent.duration)
      eventTimer.restart()
    } else {
      currentEvent = null
      eventTimer.stop()
    }
  }

  Timer {
    id: eventTimer
    onTriggered: root.advance()
  }

  // ---------------------------------------------------- OSD takeover

  // Same contract as the stock omarchy.osd: shell.summon("omarchy.osd", …)
  // reaches open() through the clone, and `omarchy-shell osd show` lands here.
  readonly property bool opened: currentEvent !== null && currentEvent.kind === "osd"

  function open(payloadJson) {
    pushEvent(Model.osdEventFromPayload(payloadJson, settings.osdDuration))
  }

  function close() {
    if (currentEvent && currentEvent.kind === "osd") advance()
  }

  IpcHandler {
    target: "osd"
    function show(payloadJson: string): string { root.open(payloadJson); return "ok" }
    function close(): string { root.close(); return "ok" }
    function state(): string { return root.opened ? "open" : "closed" }
    function ping(): string { return "ok" }
  }

  IpcHandler {
    target: "omanotch"
    function calibrate(): string { root.startCalibration(); return "ok" }
    function expand(): string { root.pinned = true; return "ok" }
    function collapse(): string { root.pinned = false; root.hovered = false; return "ok" }
    function toggle(): string { root.pinned = !root.pinned; return root.pinned ? "expanded" : "collapsed" }
    function state(): string { return root.islandState }
    function status(): string {
      return JSON.stringify({
        state: root.islandState, notchWidth: root.notchWidth, notchHeight: root.notchHeight,
        visualizer: root.visualizerMode, cava: root.cavaAvailable, media: root.hasMedia,
        playing: root.mediaPlaying, event: root.currentEvent ? root.currentEvent.kind : "",
        queued: root.queue.length, screen: root.notchScreen ? root.notchScreen.name : "",
        battery: {
          present: root.batteryPresent, upowerOnBattery: UPower.onBattery === true,
          usingBattery: root.usingBattery, state: root.batteryState,
          percent: root.batteryPercent, timeToEmpty: root.battery ? root.battery.timeToEmpty : 0,
          timeToFull: root.battery ? root.battery.timeToFull : 0,
          isLaptop: root.battery ? root.battery.isLaptopBattery === true : false,
          devices: UPower.devices && UPower.devices.values ? UPower.devices.values.length : -1
        }
      })
    }
    function ping(): string { return "ok" }
  }

  // ------------------------------------------------------ calibration

  function startCalibration() {
    calWidth = settings.notchWidth
    calHeight = settings.notchHeight
    calibrating = true
    pinned = false
  }

  function finishCalibration(save) {
    if (save && shell && typeof shell.mutateShellConfig === "function") {
      shell.mutateShellConfig(Model.settingsMutator(pluginId, { notchWidth: calWidth, notchHeight: calHeight }))
    }
    calibrating = false
  }

  function calibrationKey(event) {
    var step = Model.calibrationStep(event.key, (event.modifiers & Qt.ShiftModifier) !== 0, { notchWidth: calWidth, notchHeight: calHeight })
    if (!step) return false
    if (step.action === "save") finishCalibration(true)
    else if (step.action === "cancel") finishCalibration(false)
    else { calWidth = step.notchWidth; calHeight = step.notchHeight }
    return true
  }

  // --------------------------------------------------------- island state

  property bool hovered: false
  property bool pinned: false
  readonly property bool expanded: (hovered || pinned) && !calibrating
  readonly property string expandedMode: hasMedia ? "media" : "dashboard"
  readonly property string islandState: Model.resolveState({
    calibrating: calibrating, event: currentEvent, expanded: expanded, mediaPlaying: mediaPlaying
  })

  // OSD events keep showing inside the expanded card instead of collapsing it.
  readonly property var inlineOsd: expanded && currentEvent && currentEvent.kind === "osd" ? currentEvent : null

  TextMetrics {
    id: eventMetrics
    font.family: root.fontFamily
    font.pixelSize: root.bodySize
    font.bold: true
    text: {
      var e = root.currentEvent
      if (!e || e.hasProgress) return ""
      var t = String(e.title || "")
      var m = String(e.message || "")
      return t && m ? t + "  " + m : (t || m)
    }
  }

  // Geometry follows the live calibration values, not the saved ones.
  readonly property var geometry: {
    var g = {}
    for (var k in settings) g[k] = settings[k]
    g.notchWidth = notchWidth
    g.notchHeight = notchHeight
    return g
  }

  readonly property var islandSize: Model.islandSize(islandState, geometry, {
    kind: currentEvent ? currentEvent.kind : "",
    hasProgress: currentEvent ? currentEvent.hasProgress === true : false,
    textWidth: eventMetrics.advanceWidth,
    pad: pad,
    mode: expandedMode,
    showClock: settings.showClock
  })

  readonly property var notchScreen: {
    var list = Quickshell.screens
    for (var i = 0; i < list.length; i++) {
      if (String(list[i].name || "").indexOf("eDP") === 0) return list[i]
    }
    return list.length > 0 ? list[0] : null
  }

  Timer {
    id: hoverTimer
    interval: root.settings.hoverDelay
    onTriggered: root.hovered = true
  }
  Timer {
    id: leaveTimer
    interval: root.settings.leaveDelay
    onTriggered: { root.hovered = false; root.pinned = false }
  }

  function setPointerInside(inside) {
    if (inside) { leaveTimer.stop(); if (!hovered) hoverTimer.restart() }
    else { hoverTimer.stop(); if (hovered || pinned) leaveTimer.restart() }
  }

  property real wheelAccumulator: 0
  function wheel(deltaY) {
    if (!settings.scrollVolume) return
    wheelAccumulator += deltaY
    if (wheelAccumulator >= 60) {
      wheelAccumulator = 0
      Quickshell.execDetached(["omarchy-audio-output-volume", "raise"])
    } else if (wheelAccumulator <= -60) {
      wheelAccumulator = 0
      Quickshell.execDetached(["omarchy-audio-output-volume", "lower"])
    }
  }

  // --------------------------------------------------------------- window

  PanelWindow {
    id: window
    screen: root.notchScreen
    visible: root.notchScreen !== null
    anchors { top: true; left: true; right: true }
    implicitHeight: Math.max(root.islandSize.height, root.notchHeight * 5 + 40) + 40
    color: "transparent"
    WlrLayershell.namespace: "omarchy-omanotch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.calibrating ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Only the island takes input; the rest of the strip passes clicks through.
    mask: Region { item: island }

    Item {
      id: keys
      anchors.fill: parent
      focus: root.calibrating
      Keys.onPressed: function(event) { if (root.calibrating && root.calibrationKey(event)) event.accepted = true }
      onFocusChanged: if (focus) forceActiveFocus()
    }

    Item {
      id: island
      x: Math.round((parent.width - width) / 2)
      y: 0
      width: root.islandSize.width
      height: root.islandSize.height

      Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
      Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

      readonly property bool widened: width > root.notchWidth + 1 || height > root.notchHeight + 1
      readonly property int filletSize: Math.round(root.notchHeight * 0.3)
      readonly property color fill: root.calibrating ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.85) : root.islandColor

      Rectangle {
        id: shape
        anchors.fill: parent
        color: island.fill
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.islandSize.radius
        bottomRightRadius: root.islandSize.radius
        Behavior on bottomLeftRadius { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        Behavior on bottomRightRadius { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
      }

      Fillet {
        x: -width
        y: 0
        width: island.filletSize
        height: island.filletSize
        fill: island.fill
        visible: island.widened
        opacity: island.widened ? 1 : 0
      }
      Fillet {
        x: island.width
        y: 0
        width: island.filletSize
        height: island.filletSize
        fill: island.fill
        mirrored: true
        visible: island.widened
        opacity: island.widened ? 1 : 0
      }

      // Click toggles the card open for touchpad use. Controls on the cards
      // are MouseAreas, so their presses stop above this one.
      MouseArea {
        anchors.fill: parent
        onClicked: if (!root.calibrating) root.pinned = !root.pinned
      }
      HoverHandler {
        onHoveredChanged: root.setPointerInside(hovered)
      }
      WheelHandler {
        enabled: !root.expanded
        onWheel: function(event) { root.wheel(event.angleDelta.y) }
      }

      // ------------------------------------------------------- views

      CompactMedia {
        anchors.fill: parent
        notch: root
        opacity: root.islandState === "compact" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
      }

      EventRow {
        anchors.fill: parent
        notch: root
        event: root.currentEvent
        opacity: root.islandState === "event" && root.currentEvent && root.currentEvent.kind !== "notification" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
      }

      NotificationRow {
        anchors.fill: parent
        notch: root
        event: root.currentEvent
        opacity: root.islandState === "event" && root.currentEvent && root.currentEvent.kind === "notification" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
      }

      NowPlaying {
        anchors.fill: parent
        notch: root
        opacity: root.islandState === "expanded" && root.expandedMode === "media" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
      }

      Dashboard {
        anchors.fill: parent
        notch: root
        opacity: root.islandState === "expanded" && root.expandedMode === "dashboard" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
      }

      // An OSD that arrives while the card is open draws in the right ear
      // rather than collapsing the card.
      InlineOsd {
        x: island.width - width
        y: 0
        width: Math.max(0, (island.width - root.notchWidth) / 2)
        height: root.notchHeight
        notch: root
        event: root.inlineOsd
        opacity: root.inlineOsd ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
      }
    }

    // Calibration readout under the island.
    Rectangle {
      visible: root.calibrating
      anchors.horizontalCenter: parent.horizontalCenter
      y: island.height + root.gap
      width: calText.implicitWidth + root.pad * 2
      height: calText.implicitHeight + root.gap * 2
      radius: root.gap
      color: Qt.rgba(0, 0, 0, 0.85)
      border.width: 1
      border.color: root.accent
      Text {
        id: calText
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: root.calWidth + " × " + root.calHeight + " px\n← → width   ↑ ↓ height   shift = faster\n⏎ save   esc cancel"
        color: root.ink
        font.family: root.fontFamily
        font.pixelSize: root.captionSize
        textFormat: Text.PlainText
      }
    }
  }
}

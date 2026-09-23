import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "workspace.icons"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // Window representing the workspace: the active one if present,
  // else the first. HyprlandToplevel has no appId itself (docs:
  // quickshell.org Quickshell.Hyprland/HyprlandToplevel) - it comes
  // from wayland.appId (null until the address is reported), with
  // lastIpcObject.class as fallback.
  function shownToplevel(workspace) {
    if (!workspace || !workspace.toplevels) return null
    var values = workspace.toplevels.values
    if (!values || values.length === 0) return null
    for (var i = 0; i < values.length; i++) {
      try {
        if (values[i] && values[i].activated) return values[i]
      } catch (e) {}
    }
    return values[0]
  }

  function toplevelAppId(toplevel) {
    if (!toplevel) return ""
    try {
      if (toplevel.wayland && toplevel.wayland.appId) return String(toplevel.wayland.appId)
    } catch (e) {}
    try {
      var ipc = toplevel.lastIpcObject
      if (ipc && ipc.class) return String(ipc.class)
    } catch (e) {}
    return ""
  }

  // Omarchy TUI launchers run under synthetic app-ids like
  // org.omarchy.<cmd> (see omarchy-launch-tui) which have no desktop
  // entry. Strip the prefix so btop etc. still resolve.
  function candidatesFor(appId) {
    var out = [appId]
    var prefix = "org.omarchy."
    if (appId.indexOf(prefix) === 0) {
      var cmd = appId.slice(prefix.length)
      out.push(cmd)
      var launchPrefix = "omarchy-launch-"
      if (cmd.indexOf(launchPrefix) === 0) out.push(cmd.slice(launchPrefix.length))
    }
    return out
  }

  // Launcher ids with no desktop entry at all: map to a themed icon.
  function aliasVisual(appId) {
    var table = {
      "org.omarchy.omarchy-launch-docker-tui": [["lazydocker", "Docker"], ["docker", "Docker"]]
    }
    var rows = table[appId]
    if (!rows) return null
    for (var i = 0; i < rows.length; i++) {
      var hit = ""
      try { hit = Quickshell.iconPath(rows[i][0], true) } catch (e) {}
      if (hit) return { icon: rows[i][0], name: rows[i][1] }
    }
    return null
  }

  // Returns a DesktopEntry or a plain {icon, name}; null when unknown.
  function entryForAppId(appId) {
    if (!appId) return null
    var cands = root.candidatesFor(appId)
    for (var i = 0; i < cands.length; i++) {
      var e = null
      try { e = DesktopEntries.byId(cands[i]) } catch (err1) {}
      if (!e) {
        try { e = DesktopEntries.heuristicLookup(cands[i]) } catch (err2) {}
      }
      if (e && e.icon) return e
    }
    return root.aliasVisual(appId)
  }

  // Position of a window from its last IPC snapshot ([x, y]).
  function posOf(toplevel) {
    try {
      var ipc = toplevel ? toplevel.lastIpcObject : null
      if (ipc && ipc.at && ipc.at.length === 2) {
        return { x: Number(ipc.at[0]), y: Number(ipc.at[1]), floating: !!ipc.floating }
      }
    } catch (e) {}
    return null
  }

  // Windows in tile order: tiled first, left-to-right then top-to-bottom.
  function sortedWins(winList) {
    var wins = (winList || []).slice()
    wins.sort(function(a, b) {
      var pa = root.posOf(a), pb = root.posOf(b)
      if (!pa && !pb) return 0
      if (!pa) return 1
      if (!pb) return -1
      if (pa.floating !== pb.floating) return pa.floating ? 1 : -1
      if (pa.x !== pb.x) return pa.x - pb.x
      return pa.y - pb.y
    })
    return wins
  }

  // One entry per window on the workspace (same app twice = icon twice).
  // The focused window is flagged so its icon highlights; floating
  // windows are flagged for the floating badge.
  function iconListFor(winList) {
    var out = []
    var wins = root.sortedWins(winList)
    for (var i = 0; i < wins.length; i++) {
      var aid = root.toplevelAppId(wins[i])
      if (!aid) continue
      var e = root.entryForAppId(aid)
      if (e && e.icon) {
        var isActive = false
        try { isActive = !!wins[i].activated } catch (err) {}
        var pos = root.posOf(wins[i])
        out.push({ appId: aid, icon: String(e.icon), label: e.name ? String(e.name) : aid, active: isActive, floating: pos ? pos.floating : false })
      }
    }
    return out
  }

  function tooltipFor(iconList, numberText) {
    if (!iconList || iconList.length === 0) return "Workspace " + numberText
    var names = []
    for (var i = 0; i < iconList.length; i++) {
      var suffix = (iconList[i].floating ? " (floating)" : "") + (iconList[i].active ? " ●" : "")
      names.push(iconList[i].label + suffix)
    }
    return numberText + " · " + names.join(", ")
  }

  // Scratchpad = Hyprland special workspace (negative id). Null when absent.
  function specialWorkspace() {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id < 0) return values[i]
    }
    return null
  }

  function toggleSpecial() {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch togglespecialworkspace")
  }

  function iconSourceFor(iconName) {
    var lib = (root.bar && root.bar.shell) ? root.bar.shell.appLibrary : null
    if (lib && typeof lib.iconSource === "function") return lib.iconSource(iconName)
    if (!iconName) return ""
    var themed = Quickshell.iconPath(iconName, true)
    if (themed) return themed
    return Quickshell.iconPath("application-x-executable", true)
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  readonly property real iconSize: Math.max(14, root.barSize - 12)

  // lastIpcObject goes stale on move/swap (docs: refresh via
  // Hyprland.refreshToplevels), so re-fetch positions periodically
  // to keep icon order matching tile order.
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: Hyprland.refreshToplevels()
  }

  readonly property var specialWs: root.specialWorkspace()
  readonly property var specialTops: {
    if (!specialWs || !specialWs.toplevels || !specialWs.toplevels.values) return []
    return specialWs.toplevels.values
  }
  readonly property var specialIcons: root.iconListFor(specialTops)
  readonly property bool showSpecial: specialIcons.length > 0

  implicitWidth: contentRow.implicitWidth + trailingGap
  implicitHeight: contentRow.implicitHeight

  GridLayout {
    id: contentRow
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : 3
    columnSpacing: Style.space(3)
    rowSpacing: Style.space(2)

    GridLayout {
      id: grid
      columns: root.vertical ? 1 : root.workspaceIds().length
      columnSpacing: root.vertical ? 0 : Style.space(1)
      rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: wsBtn
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
        readonly property var winList: {
          if (!workspace || !workspace.toplevels || !workspace.toplevels.values) return []
          return workspace.toplevels.values
        }
        readonly property var iconList: root.iconListFor(winList)
        readonly property bool showIcons: iconList.length > 0
        readonly property string numberText: modelData === 10 ? "0" : String(modelData)

        bar: root.bar
        // Internal label hidden: content below draws number + all app
        // icons side by side. Text stays non-empty so the slot keeps space.
        text: numberText
        labelVisible: false
        active: focused
        tooltipText: root.tooltipFor(iconList, numberText)
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : (showIcons ? numText.implicitWidth + Style.space(4) + iconList.length * root.iconSize + (iconList.length - 1) * Style.space(3) + Style.spaceReal(12) : Style.space(20))
        fixedHeight: root.vertical && showIcons ? root.barSize + iconList.length * (root.iconSize + Style.space(2)) + Style.space(4) : root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }

        GridLayout {
          anchors.centerIn: parent
          columns: root.vertical ? 1 : (wsBtn.iconList.length + 1)
          columnSpacing: Style.space(4)
          rowSpacing: Style.space(2)

          Text {
            id: numText
            Layout.alignment: Qt.AlignVCenter
            textFormat: Text.PlainText
            text: wsBtn.numberText
            color: wsBtn.focused ? Color.foreground : wsBtn.foreground
            font.family: wsBtn.bar ? wsBtn.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.body
            font.weight: wsBtn.focused ? Font.Bold : Font.Normal
            renderType: Text.NativeRendering
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          // One icon per window on this workspace (full-color artwork,
          // like the launcher; number/focus chrome follows the theme).
          // The focused window's icon is full-bright with an accent
          // tick; the rest are dimmed. Floating windows get a badge.
          Repeater {
            model: wsBtn.iconList

            Column {
              required property var modelData
              spacing: 1
              Layout.alignment: Qt.AlignVCenter
              Layout.topMargin: 2

              Item {
                width: root.iconSize
                height: root.iconSize

                Image {
                  anchors.fill: parent
                  fillMode: Image.PreserveAspectFit
                  sourceSize.width: width * Screen.devicePixelRatio
                  sourceSize.height: height * Screen.devicePixelRatio
                  source: root.iconSourceFor(modelData.icon)
                  asynchronous: true
                  opacity: modelData.active ? 1 : 0.45
                }

                Rectangle {
                  visible: modelData.floating
                  width: 7
                  height: 7
                  radius: 3.5
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.rightMargin: -2
                  anchors.topMargin: -2
                  color: Color.accent
                  border.color: Color.background
                  border.width: 1
                }
              }

              Rectangle {
                width: 10
                height: 2
                radius: 1
                anchors.horizontalCenter: parent.horizontalCenter
                color: modelData.active ? Color.accent : "transparent"
                transform: Translate { y: 1 }
              }
            }
          }
        }

        // (Per-window accent ticks below mark the focused window's icon.)
      }
    }
  }

    Rectangle {
      visible: root.showSpecial
      color: Color.muted
      opacity: 0.4
      Layout.preferredWidth: root.vertical ? 20 : 1
      Layout.preferredHeight: root.vertical ? 1 : 20
      Layout.alignment: Qt.AlignCenter
    }

    // Dedicated scratchpad slot: hidden entirely when empty.
    // Click an icon to toggle the special workspace.
    RowLayout {
      visible: root.showSpecial
      spacing: Style.space(3)

      Repeater {
        model: root.specialIcons

        WidgetButton {
          id: spBtn
          required property var modelData
          bar: root.bar
          text: " "
          labelVisible: false
          tooltipText: modelData.label + (modelData.floating ? " (floating)" : "") + " · scratchpad"
          fixedWidth: root.iconSize + Style.spaceReal(10)
          fixedHeight: root.barSize
          onPressed: function() { root.toggleSpecial() }

          Column {
            anchors.centerIn: parent
            spacing: 1

            Item {
              width: root.iconSize
              height: root.iconSize

              Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
                source: root.iconSourceFor(spBtn.modelData.icon)
                asynchronous: true
                opacity: spBtn.modelData.active ? 1 : 0.45
              }

              Rectangle {
                visible: spBtn.modelData.floating
                width: 7
                height: 7
                radius: 3.5
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -2
                anchors.topMargin: -2
                color: Color.accent
                border.color: Color.background
                border.width: 1
              }
            }

            Rectangle {
              width: 10
              height: 2
              radius: 1
              anchors.horizontalCenter: parent.horizontalCenter
              color: spBtn.modelData.active ? Color.accent : "transparent"
              transform: Translate { y: 1 }
            }
          }
        }
      }
    }
  }
}

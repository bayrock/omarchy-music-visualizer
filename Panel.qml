import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Omarchy shell plugin for Music Visualizer.
//
// The visualizer itself is mpv rendering an ffmpeg filter graph
// (bin/music-visualizer), so this "panel" has no window of its own. It owns the
// visualizer process, answers the shell's summon/hide/toggle IPC, and fades the
// running visualizer to the new colors whenever the Omarchy theme changes.
//
//   omarchy-shell shell toggle bayrock.music-visualizer '{}'
//   omarchy-shell shell summon bayrock.music-visualizer '{"src":"daft punk around the world"}'
//   omarchy-shell shell call   bayrock.music-visualizer play 'https://youtu.be/...'
//   omarchy-shell shell call   bayrock.music-visualizer status ''
Item {
  id: root

  // injected by the shell; __sourceDir is this plugin's checkout
  property var manifest
  readonly property string script: (manifest && manifest.__sourceDir ? manifest.__sourceDir : "") + "/bin/music-visualizer"

  // read by the shell's toggle(): open while the visualizer process runs
  readonly property bool opened: viz.running

  property var pendingCommand: null
  // set when the visualizer starts and cleared only when it really exits, so it is
  // still accurate during teardown (when the child Process may already be gone)
  property bool vizAlive: false
  // plain copy of the script path for teardown, when `manifest` may already be gone
  property string liveScript: ""

  // payload (JSON, optional): {"src": "<URL | file | search terms>", "label": "<header text>"}
  function open(payload) {
    let p = {}
    try { p = payload ? JSON.parse(payload) : {} } catch (e) { p = {} }
    const cmd = [root.script, "start"]
    if (p && p.src) {
      cmd.push(String(p.src))
      if (p.label) cmd.push(String(p.label))
    }
    if (viz.running) {
      // a new track while one is playing: restart with it
      if (cmd.length === 2) return
      root.pendingCommand = cmd
      root.close()
      return
    }
    root.liveScript = root.script
    viz.command = cmd
    viz.running = true
  }

  function close() {
    if (viz.running) stopper.running = true
  }

  function toggle() {
    if (viz.running) root.close()
    else root.open("")
  }

  // `call ... play "<URL | file | search terms>"`
  function play(src) {
    root.open(JSON.stringify({ src: String(src || "") }))
  }

  function status() {
    return viz.running ? "on" : "off"
  }

  Process {
    id: viz
    onStarted: root.vizAlive = true
    onExited: {
      root.vizAlive = false
      if (root.pendingCommand) {
        viz.command = root.pendingCommand
        root.pendingCommand = null
        viz.running = true
      }
    }
  }

  Process {
    id: stopper
    command: [root.script, "off"]
  }

  // The plugin is unloading (disabled, removed, updated, shell restart): don't
  // leave an orphaned visualizer playing that a later toggle can't see.
  Component.onDestruction: if (root.vizAlive && root.liveScript) Quickshell.execDetached([root.liveScript, "off"])

  // --- live theming: the shell updates Color when the theme changes. Several
  // roles change in quick succession, so debounce them into one retheme.
  Connections {
    target: Color
    function onAccentChanged() { rethemeDebounce.restart() }
    function onBackgroundChanged() { rethemeDebounce.restart() }
    function onForegroundChanged() { rethemeDebounce.restart() }
  }

  Timer {
    id: rethemeDebounce
    interval: 250
    onTriggered: if (viz.running) Quickshell.execDetached([root.script, "retheme"])
  }
}

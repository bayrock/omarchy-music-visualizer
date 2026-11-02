# Music Visualizer

**A 1337 hacker-terminal music visualizer inspired by php2shell, drawn in your
[Omarchy](https://omarchy.org) theme colors.**

Play any song and watch it as a scrolling spectrogram, a live hex dump,
frequency bars and a waveform under a fake `php2shell` exploit session. Switch
themes while it plays and the colors fade smoothly to the new palette.

![Music Visualizer in the Matte Black theme](preview.png)

- **Plays almost anything:** a YouTube or SoundCloud link, a local audio file,
  or plain search terms. Each track loops until you close it.
- **Uses your theme:** colors come from your Omarchy theme and update live
  when you switch.
- **Fast to reopen:** songs are cached after the first play, so a repeat
  launch opens in under half a second.
- **Nothing extra to install:** everything it needs is part of a standard
  Omarchy install.

## Install

**1. Add the plugin:**

```bash
omarchy plugin add https://github.com/bayrock/omarchy-music-visualizer.git --enable
```

**2. Give it a shortcut.** This adds <kbd>Super</kbd>+<kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>V</kbd>,
which is unused in stock Omarchy:

```bash
cat >> ~/.config/hypr/bindings.lua <<'EOF'
o.bind("SUPER + CTRL + SHIFT + V", "Music visualizer", "omarchy-shell shell toggle bayrock.music-visualizer '{}'")
EOF
```

Press it to start the visualizer, and press it again to close it. The first
launch streams the default track. After that, it starts almost instantly.

> Like every Omarchy plugin, this runs unsandboxed with your user's
> permissions. The code is short (`Panel.qml` and `bin/music-visualizer`), so
> give it a read first.

### Optional: add it to the Omarchy menu

In `~/.config/omarchy/extensions/omarchy-menu.jsonc`, add this line inside the
top-level `{ }`. It appears under **Trigger → Toggle**, with a checkmark while
it's playing:

```jsonc
"trigger.toggle.music-visualizer": {"icon":"󰐰","label":"Music Visualizer","action":"omarchy-shell shell toggle bayrock.music-visualizer '{}'","checked":"[[ $(omarchy-shell shell call bayrock.music-visualizer status '') == on ]]"},
```

## Play your own music

```bash
# YouTube search: plays the top result
omarchy-shell shell summon bayrock.music-visualizer '{"src":"daft punk around the world"}'

# a link (YouTube, SoundCloud, Bandcamp, ... anything yt-dlp supports)
omarchy-shell shell summon bayrock.music-visualizer '{"src":"https://www.youtube.com/watch?v=..."}'

# a local file, with your own header text
omarchy-shell shell summon bayrock.music-visualizer '{"src":"~/Music/track.flac","label":"My Track"}'
```

If a visualizer is already open, it switches to the new track. The header and
window title show the track's real title once it starts playing.

**In the window:** <kbd>f</kbd> fullscreen · <kbd>space</kbd> pause ·
<kbd>9</kbd>/<kbd>0</kbd> volume · <kbd>m</kbd> mute · <kbd>q</kbd> quit.
It opens as a floating, centered window, Omarchy's default for media windows.

## Settings

Create `~/.config/music-visualizer/config` (plain `key = value` lines). This
keeps your settings out of the plugin folder, so updates never conflict with
them:

```ini
# what the shortcut plays: a link, file or search terms
track = https://www.youtube.com/watch?v=...
# header text for that track (optional: defaults to the track's title)
label = My favorite song
# "green" for the classic matrix-green look instead of your theme colors
palette = theme
```

Changes apply the next time the visualizer opens.

## Update or remove

```bash
omarchy plugin update bayrock.music-visualizer && omarchy restart shell
omarchy plugin remove bayrock.music-visualizer
```

The shell keeps the plugin's compiled code until it restarts, so restart it
after updating to load the new version.

After removing it, also delete the shortcut line from
`~/.config/hypr/bindings.lua`, plus the menu entry if you added one. To delete
the cached songs and settings too:

```bash
rm -rf ~/.cache/music-visualizer ~/.config/music-visualizer
```

## Troubleshooting

- **The shortcut does nothing.** Run
  `omarchy-shell shell call bayrock.music-visualizer status ''`. If it prints
  `unknown`, the plugin isn't enabled: run
  `omarchy plugin enable bayrock.music-visualizer`.
- **You see a "couldn't play that" notification.** The link, file or search
  returned nothing playable, or you're offline. YouTube sometimes changes
  things in a way that breaks downloads until yt-dlp is updated, and
  `omarchy update` updates it.
- **A new song takes a couple of seconds to start.** That's expected the first
  time: it's streamed while it's saved to the cache. Later plays start almost
  instantly.
- **The window is small.** Press <kbd>f</kbd> for fullscreen, or resize it like
  any floating window.

## Privacy and storage

The default track and any links or searches you play are fetched from their
sites through `yt-dlp`, and the audio is saved under `~/.cache/music-visualizer/`
(a few MB per song) for fast replays. Local files are played directly and never
copied. Nothing else leaves your machine.

## How it works

- **Drawing:** `bin/music-visualizer` runs mpv with an FFmpeg filter graph
  (`showspectrum`, `showfreqs`, `showwaves`, `drawtext`). The graph draws a
  color-neutral mask, and a single `colorchannelmixer` maps it to your theme's
  background, accent, foreground and red.
- **Theme changes:** the plugin watches the shell's theme colors. On a change,
  it steps that mixer to the new palette over ~0.8 s through mpv's IPC socket.
  The audio is never touched.
- **Safety:** mpv runs with `--no-config` (so your personal mpv setup can't
  change it) and inside a 1.5 GB memory-capped systemd scope (normal use is
  ~400 MB).

Requirements, all part of Omarchy's base install: `mpv`, `yt-dlp`, `socat`,
`jq` and the JetBrainsMono Nerd Font.

## License

[MIT](LICENSE) © 2026 shojo.me. The default track is streamed from YouTube and
isn't distributed with this plugin.

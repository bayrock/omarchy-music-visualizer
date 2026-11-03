# Music Visualizer

**A 1337 hacker-terminal music visualizer inspired by php2shell, drawn in your
[Omarchy](https://omarchy.org) theme colors.**

Play any song and watch it as a scrolling spectrogram, a live hex dump,
frequency bars and a waveform under a fake `php2shell` exploit session. Switch
themes while it plays and the colors fade smoothly to the new palette.

![Music Visualizer in the Matte Black theme](preview.png)

- **Shuffle out of the box:** opens into a hacker-trance mix (trance anthems
  plus Hackers and Matrix soundtrack cuts). Press <kbd>Tab</kbd> to skip, or
  shuffle your own playlist or music folder.
- **Type to change the song:** start typing in the window and your search
  appears in the hacker prompt. Press <kbd>Enter</kbd> and it plays.
- **Plays almost anything:** a YouTube or SoundCloud link, a local audio file,
  or plain search terms. A song you pick loops until you change it.
- **Works with your media keys:** play/pause controls it, Next skips in
  shuffle, and Omarchy's media widgets show the current track.
- **Uses your theme:** colors come from your Omarchy theme and update live
  when you switch.
- **Fast to reopen:** songs are cached after the first play, so a repeat
  launch opens in under half a second.
- **Nothing extra to install:** everything it needs is part of a standard
  Omarchy install.

## Install

Music Visualizer is listed on the
[Omarchy plugin hub](https://omarchyplugins.com/plugin.html?id=bayrock.music-visualizer).

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

Press it to start the visualizer, and press it again to close it. It opens
shuffling the built-in mix, and moves to a new track each time one ends. Press
<kbd>Tab</kbd> to skip, or just start typing to search for a song (see below).

> Like every Omarchy plugin, this runs unsandboxed with your user's
> permissions. The code is short (`Panel.qml`, `bin/music-visualizer` and
> `lua/search.lua`), so give it a read first.

### Optional: add it to the Omarchy menu

In `~/.config/omarchy/extensions/omarchy-menu.jsonc`, add this line inside the
top-level `{ }`. It appears under **Trigger → Toggle**, with a checkmark while
it's playing:

```jsonc
"trigger.toggle.music-visualizer": {"icon":"󰐰","label":"Music Visualizer","action":"omarchy-shell shell toggle bayrock.music-visualizer '{}'","checked":"[[ $(omarchy-shell shell call bayrock.music-visualizer status '') == on ]]"},
```

## Shuffle

The visualizer opens in shuffle: random tracks from a playlist, each played
once before any repeats. The header shows where you are and what's coming:

```
[#] STAGE  SHUFFLE :: track 7/40 :: next: Orbital - Halcyon On and On
```

- <kbd>Tab</kbd> or the Next media key skips to the next track. The next one
  is looked up while the current one plays, so there's no gap.
- Searching for a song (below) leaves shuffle and loops your song.
  <kbd>Tab</kbd> goes back to shuffle.
- The built-in playlist, **hacker-trance**, is classic trance anthems (ATB,
  Paul van Dyk, Gouryella, System F...) plus hacker-film soundtrack cuts
  (Orbital, Propellerheads, Juno Reactor, Daft Punk's Tron...). See
  [`playlists/hacker-trance.txt`](playlists/hacker-trance.txt).

To shuffle your own music, set `playlist` in your [settings](#settings) to a
YouTube or SoundCloud playlist link, a music folder, or a text file with one
song per line (search terms, a link or a file). If it can't be read, the
built-in playlist plays instead.

## Play your own music

**Just start typing.** With the visualizer window focused, type a song name.
Your text appears in the terminal prompt at the top
(`./php2shell --search "daft punk around the world█"`). Press
<kbd>Enter</kbd>:

1. The header shows `[~] SEARCH resolving`, and the current song keeps playing
   while it looks yours up (a couple of seconds).
2. The new song starts in the same window, and the header and window title
   show its real title.
3. If nothing matches, the header shows `[!] ERROR no match` and the current
   song carries on.

You can also paste a link (<kbd>Ctrl</kbd>+<kbd>V</kbd>), such as a YouTube,
SoundCloud or Bandcamp URL. Songs you've played before start instantly
because they're cached.

### Keys in the window

| Key | What it does |
|---|---|
| any letter, number or symbol | start a search (it types into the prompt) |
| <kbd>Enter</kbd> | play what you typed (loops it, leaving shuffle) |
| <kbd>Esc</kbd> | cancel the search (or leave fullscreen) |
| <kbd>Backspace</kbd> · <kbd>Ctrl</kbd>+<kbd>W</kbd> · <kbd>Ctrl</kbd>+<kbd>U</kbd> | delete a character · a word · everything |
| <kbd>Ctrl</kbd>+<kbd>V</kbd> | paste (links work too) |
| <kbd>Tab</kbd> | shuffle: play a random track, or skip to the next one |
| <kbd>Space</kbd> | pause / resume (while searching it types a space, unless paused) |
| <kbd>↑</kbd> / <kbd>↓</kbd> | volume |
| <kbd>F11</kbd> or double-click | fullscreen |
| <kbd>Ctrl</kbd>+<kbd>Q</kbd> | quit (your shortcut and <kbd>Super</kbd>+<kbd>W</kbd> also close it) |

Since typing searches, letters aren't shortcuts. That's why fullscreen and
quit use <kbd>F11</kbd> and <kbd>Ctrl</kbd>+<kbd>Q</kbd>. Your keyboard's media
keys work too: play/pause, and Next skips in shuffle.

It opens as a floating, centered window, Omarchy's default for media windows.

### From scripts or other keybinds

Open the visualizer with a specific song, or switch the open one to it:

```bash
# YouTube search: plays the top result
omarchy-shell shell summon bayrock.music-visualizer '{"src":"daft punk around the world"}'

# a link (YouTube, SoundCloud, Bandcamp, ... anything yt-dlp supports)
omarchy-shell shell summon bayrock.music-visualizer '{"src":"https://www.youtube.com/watch?v=..."}'

# a local file, with your own header text
omarchy-shell shell summon bayrock.music-visualizer '{"src":"~/Music/track.flac","label":"My Track"}'

# shuffle
omarchy-shell shell summon bayrock.music-visualizer '{"src":"shuffle"}'
```

The plugin's script also works directly from a terminal. Run it with `--help`
for every command and key:

```bash
~/.config/omarchy/plugins/bayrock.music-visualizer/bin/music-visualizer --help
```

Its commands are `start`, `load` (switch the open visualizer to a new song),
`off`, `status`, `retheme` and `config`.

## Settings

Everything works without settings. To change something, run:

```bash
~/.config/omarchy/plugins/bayrock.music-visualizer/bin/music-visualizer config
```

That creates `~/.config/music-visualizer/config` with every setting explained,
and opens it in your editor. It lives outside the plugin folder, so updates
never touch it. It's plain `name = value` lines; put a `#` in front of a line
to go back to the default:

```ini
# What plays when it opens: shuffle (default), search terms, a link, or a file
track = shuffle

# Header text for that track (optional: defaults to the track's real title)
#label = My favorite song

# What shuffle plays: hacker-trance (default), a playlist link, a music folder,
# or a text file with one song per line
playlist = hacker-trance

# Colors: theme (follow your Omarchy theme, default) or green (classic matrix)
palette = theme
```

Examples: `track = daft punk around the world` always opens on that song;
`playlist = ~/Music` shuffles your music folder;
`playlist = https://www.youtube.com/playlist?list=...` shuffles a YouTube
playlist (refreshed daily). Changes apply the next time the visualizer opens.
The full template is [`config.example`](config.example).

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
- **You see a "couldn't play that" notification, or `[!] ERROR` in the
  header.** The link, file or search returned nothing playable, or you're
  offline. YouTube sometimes changes things in a way that breaks downloads
  until yt-dlp is updated, and `omarchy update` updates it.
- **Typing does nothing.** Click the visualizer window first so it has keyboard
  focus.
- **The picture froze.** It's paused: a "PAUSED" sign shows, and
  <kbd>Space</kbd> resumes. (Before 1.3.1 there was no sign, and typing while
  paused turned <kbd>Space</kbd> into a typed space.)
- **Shuffle shows `next: (lookup failed: Tab to retry)`.** A track couldn't be
  found, usually a connection hiccup. Press <kbd>Tab</kbd>. A track that won't
  play is skipped automatically.
- **My playlist isn't used.** Check the `playlist` line with
  `music-visualizer config`. A folder needs audio files in it, and a text
  file needs one song per line. If it can't be read, the built-in playlist
  plays instead.
- **A new song takes a couple of seconds to start.** That's expected the first
  time: it's streamed while it's saved to the cache. Later plays start almost
  instantly.
- **The window is small.** Press <kbd>F11</kbd> (or double-click) for
  fullscreen, or resize it like any floating window.
- **Media keys don't reach it.** It needs `mpv-mpris`, which Omarchy installs
  by default. If another player is also open, the media keys control whichever
  one Omarchy treats as active.

## Privacy and storage

Songs, links, searches and playlist links you play are fetched from their
sites through `yt-dlp`, and the audio is saved under `~/.cache/music-visualizer/`
(a few MB per song) for fast replays. The cache is capped at 1 GB, and the
least recently played songs are removed first. Local files are played directly
and never copied. Nothing else leaves your machine.

## How it works

- **Drawing:** `bin/music-visualizer` runs mpv with an FFmpeg filter graph
  (`showspectrum`, `showfreqs`, `showwaves`, `drawtext`). The graph draws a
  color-neutral mask, and a single `colorchannelmixer` maps it to your theme's
  background, accent, foreground and red.
- **Theme changes:** the plugin watches the shell's theme colors. On a change,
  it steps that mixer to the new palette over ~0.8 s through mpv's IPC socket.
  The audio is never touched.
- **Search box:** `lua/search.lua` runs inside mpv and handles every key. While
  you type, it writes your text into the prompt line that the filter graph
  redraws each frame. On <kbd>Enter</kbd>, it passes the search to the script
  (`load`). The script resolves the song with `yt-dlp` while the old one keeps
  playing, then switches mpv over. If the new song won't play, `search.lua`
  goes back to the old one. All of this goes through a private per-run
  directory (`mktemp -d`, mode 0700).
- **Pausing:** the filter graph only makes frames while audio plays, so a
  paused picture is frozen. `search.lua` then draws a "PAUSED" sign and the
  live search prompt as an mpv OSD overlay (in your theme's accent color), and
  <kbd>Space</kbd> always resumes. Playing a search or pressing <kbd>Tab</kbd>
  resumes too.
- **Shuffle:** the script keeps a shuffled list of the playlist and queues the
  next track in mpv's own playlist while the current one plays. `search.lua`
  tells the script when mpv moves on (track ended, <kbd>Tab</kbd>, or Next), and
  the script queues the one after.
- **Media keys:** the script loads Omarchy's `mpv-mpris` add-on, so the
  visualizer shows up as an MPRIS player with the track's real title.
- **Safety:** mpv runs with `--no-config` (so your personal mpv setup can't
  change it) and inside a 1.5 GB memory-capped systemd scope (normal use is
  ~400 MB).

Requirements, all part of Omarchy's base install: `mpv`, `yt-dlp`, `socat`,
`jq` and the JetBrainsMono Nerd Font. `mpv-mpris` (also in the base install)
is optional: it enables the media keys.

## License

[MIT](LICENSE) © 2026 shojo.me. Music is streamed from YouTube and other
sites when you play it. None is distributed with this plugin; the playlists
are just song names.

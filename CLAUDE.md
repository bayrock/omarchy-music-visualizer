# Music Visualizer: working notes

Omarchy shell plugin `bayrock.music-visualizer` (GitHub: bayrock/omarchy-music-visualizer).
Files: `Panel.qml` (shell IPC), `bin/music-visualizer` (everything else), `lua/search.lua`
(keys + search box inside mpv), `playlists/*.txt` (shuffle lists), `config.example`.

## Every change ships as a release
1. Code change, tested live (launch via `omarchy-shell shell toggle bayrock.music-visualizer '{}'`
   or `bin/music-visualizer start`; drive it with mpv IPC, and never inject keypresses while the
   user may be typing in the window: check for `$RUN/typing`).
2. **README.md** updated for any user-visible change (features list, keys table, settings,
   troubleshooting, "How it works").
3. **`--help`** (`usage()` in `bin/music-visualizer`) updated to match; keep lines ≤ 80 chars.
4. **`config.example`** updated if a setting changes. Settings stay plain `name = value`, each
   explained in the file, with defaults that work without any config.
5. Bump `version` in `manifest.json` (semver), run `omarchy plugin validate "$PWD"`, commit (end
   the message with the Co-Authored-By line), tag `vX.Y.Z`, push `main` + tag.
6. Update the installed copy: `omarchy plugin update bayrock.music-visualizer --yes`. Panel.qml
   changes also need `omarchy restart shell`. The first launch right after an update may get
   killed by the panel reload, so launch again.
7. **Marketplace:** listed at https://omarchyplugins.com/plugin.html?id=bayrock.music-visualizer
   (accepted from omacom/omarchy-plugin-marketplace#13699). Installs track this repo, so a pushed
   release reaches users through `omarchy plugin update`; no comment is needed. If a change adds
   anything security-relevant (new files outside the run dir, subprocesses, capabilities), say
   so in the release commit and ask the user whether to note it on the marketplace.

## Rules
- Per-run files only inside the private `mktemp -d` run dir (a marketplace security review
  flagged a predictable `/tmp` path once). Never pass user text through a shell: use `--` for
  yt-dlp and `jq` for IPC JSON.
- No new dependencies beyond Omarchy's base install (mpv, yt-dlp, socat, jq, mpv-mpris).
- Copyright: MIT © shojo.me.

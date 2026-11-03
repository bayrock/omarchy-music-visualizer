-- Music Visualizer: keys and type-to-search, loaded into its mpv by bin/music-visualizer.
--
-- mpv runs with --no-input-default-bindings, so every key is defined here. Typing
-- any character starts a search, shown live in the visualizer's own terminal prompt
-- (prompt.txt, which drawtext re-reads every frame). Enter hands the query to
-- bin/music-visualizer (request file + SIGUSR2), which looks the song up while the
-- current one keeps playing and then switches mpv over.
--
-- Tab starts shuffle or skips to another random track; in shuffle, this script tells
-- bin/music-visualizer whenever mpv moves on to the queued next track.
--
-- Files in $MVIZ_RUN (a private per-run directory) shared with bin/music-visualizer:
--   prompt.txt / footer.txt   displayed; owned by this script while typing
--   prompt.idle / footer.idle what to show when not typing
--   typing                    present while typing
--   request                   "<command>\n<source>\n<label>\n": load | shuffle | advance
--   shuffle                   present while in shuffle mode
--   loadfail                  written when a new track failed and the old one resumed
--   colors                    "<accent> <background>" as RRGGBB, for the pause overlay
--
-- Pausing freezes the whole picture: the filter graph only makes frames while audio
-- plays, so prompt.txt changes can't show up. While paused, an OSD overlay (which
-- mpv still draws on the frozen frame) says so and mirrors the search prompt, and
-- Space always resumes, even mid-search.

local mp = require "mp"
local utils = require "mp.utils"

local RUN = os.getenv("MVIZ_RUN")
local PID = os.getenv("MVIZ_PID")
local HOST = os.getenv("MVIZ_HOST") or "localhost"
if not RUN or not PID then return end

local MAX_SHOWN = 60 -- characters of the query shown in the prompt
local CURSOR = "█"
local FOOTER_TYPING = "[ENTER] exec   [ESC] abort   [CTRL+V] paste   [CTRL+U] clear"

local typing = false
local text = ""
local cursor_on = true

local function path(name) return RUN .. "/" .. name end

local function slurp(name)
  local f = io.open(path(name), "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

-- write atomically: drawtext may be reading the file at any moment
local function put(name, s)
  local tmp = path(name .. ".lua-tmp")
  local f = io.open(tmp, "w")
  if not f then return end
  f:write(s)
  f:close()
  os.rename(tmp, path(name))
end

-- UTF-8 characters of a string
local function chars(s)
  local t = {}
  for c in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do t[#t + 1] = c end
  return t
end

local function paused() return mp.get_property_bool("pause", false) end
local function resume() mp.set_property_bool("pause", false) end

-- pause overlay ---------------------------------------------------------------------
local overlay = mp.create_osd_overlay("ass-events")

local function ass_text(s) -- literal text for ASS (U+2060 keeps a backslash literal)
  return (s:gsub("\\", "\\\226\129\160"):gsub("{", "\\{"):gsub("}", "\\}"))
end
local function ass_color(hex) -- RRGGBB -> ASS BGR
  return hex:sub(5, 6) .. hex:sub(3, 4) .. hex:sub(1, 2)
end

local prompt_line = ""

local function draw_overlay()
  if not paused() then overlay:remove(); return end
  local accent, bg = (slurp("colors") or ""):match("(%x%x%x%x%x%x) (%x%x%x%x%x%x)")
  accent, bg = ass_color(accent or "00ff41"), ass_color(bg or "020702")
  -- place things on the 1920x1080 canvas, wherever the video sits in the window
  local d = mp.get_property_native("osd-dimensions") or {}
  if not d.w or d.w <= 0 then return end
  local k = (d.w - d.ml - d.mr) / 1920
  overlay.res_x, overlay.res_y = d.w, d.h
  local function at(x, y) return ("\\pos(%d,%d)"):format(d.ml + x * k, d.mt + y * k) end
  -- the pause sign sits in the middle of the window (dy: canvas pixels below it)
  local function mid(dy) return ("\\pos(%d,%d)"):format(d.w / 2, d.h / 2 + dy * k) end
  local function fs(n) return ("\\fs%d"):format(math.max(1, n * k)) end
  local function bord(n) return ("\\bord%.1f"):format(n * k) end
  local font = "\\fnJetBrainsMono Nerd Font\\shad0"
  local ev = {}
  if typing then -- cover the frozen prompt with the live one
    ev[#ev + 1] = ("{\\an7%s\\p1\\bord0\\1c&H%s&}m 0 0 l %d 0 %d %d 0 %d{\\p0}")
      :format(at(0, 0), bg, 1405 * k, 1405 * k, 42 * k, 42 * k)
    ev[#ev + 1] = ("{\\an7%s%s\\bord0\\1c&H%s&%s}%s")
      :format(at(22, 12), fs(25), accent, font, ass_text(prompt_line))
  end
  -- see-through panel behind the sign (theme background, accent edge), so it reads
  -- as sitting above the frozen picture
  local pw, ph = 800 * k, 200 * k
  ev[#ev + 1] = ("{\\an7\\pos(%d,%d)\\p1%s\\shad0\\1c&H%s&\\1a&H50&\\3c&H%s&\\3a&H40&}m 0 0 l %d 0 %d %d 0 %d{\\p0}")
    :format(d.w / 2 - pw / 2, d.h / 2 - 115 * k, bord(2), bg, accent, pw, pw, ph, ph)
  ev[#ev + 1] = ("{\\an5%s%s\\bord0\\1c&H%s&%s}❚❚ PAUSED")
    :format(mid(-38), fs(84), accent, font)
  ev[#ev + 1] = ("{\\an5%s%s\\bord0\\1c&H%s&%s}[SPACE] resume%s")
    :format(mid(37), fs(28), accent, font, typing and "   [ENTER] play search" or "")
  overlay.data = table.concat(ev, "\n")
  overlay:update()
end

local function render()
  local shown = text
  local cs = chars(text)
  if #cs > MAX_SHOWN then -- keep the end of a long query visible
    shown = "…" .. table.concat(cs, "", #cs - MAX_SHOWN + 2)
  end
  prompt_line = ("root@%s:~# ./php2shell --search \"%s%s\""):format(HOST, shown, cursor_on and CURSOR or " ")
  put("prompt.txt", prompt_line .. "\n")
  if paused() then draw_overlay() end
end

local blink = mp.add_periodic_timer(0.5, function()
  cursor_on = not cursor_on
  render()
end)
blink:kill()

local function start_typing(initial)
  typing, text, cursor_on = true, initial or "", true
  put("typing", "")
  put("footer.txt", FOOTER_TYPING .. "\n")
  render()
  blink:resume()
end

local function stop_typing()
  typing = false
  blink:kill()
  os.remove(path("typing"))
  put("prompt.txt", slurp("prompt.idle") or "")
  put("footer.txt", slurp("footer.idle") or "")
  if paused() then draw_overlay() end
end

local function exists(name)
  local f = io.open(path(name), "r")
  if f then f:close() end
  return f ~= nil
end

-- hand a command to bin/music-visualizer (see the request file above)
local function request(cmd, src)
  put("request", cmd .. "\n" .. (src or "") .. "\n\n")
  mp.command_native_async({ name = "subprocess", args = { "kill", "-USR2", PID },
    playback_only = false }, function() end)
end

local function add(s)
  s = s:gsub("%c", "")
  if s == "" then return end
  if not typing then start_typing("") end
  text = text .. s
  cursor_on = true
  render()
end

local function submit()
  local q = text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  stop_typing()
  if q == "" then return end
  resume() -- the current song plays on while the new one is looked up
  request("load", q)
end

-- Tab: skip to the queued track if shuffle has one ready, else (re)start shuffle
local function shuffle()
  if typing then return end
  resume()
  local pos = mp.get_property_number("playlist-pos", 0)
  local count = mp.get_property_number("playlist-count", 0)
  if exists("shuffle") and count > pos + 1 then
    mp.command("playlist-next")
  else
    request("shuffle")
  end
end

local function paste()
  local clip = mp.get_property("clipboard/text")
  if not clip or clip == "" then
    local r = mp.command_native({ name = "subprocess", args = { "wl-paste", "-n" },
      capture_stdout = true, playback_only = false })
    clip = r and r.status == 0 and r.stdout or ""
  end
  clip = clip:gsub("[%c]+", " ")
  if clip ~= "" then add(clip) end
end

-- Space resumes whenever it's paused (a paused picture can't show typed spaces, and
-- it must never look stuck); otherwise it types while searching, else pauses.
local function space()
  if paused() then resume()
  elseif typing then add(" ")
  else mp.set_property_bool("pause", true) end
end

mp.observe_property("pause", "bool", draw_overlay)
mp.observe_property("osd-dimensions", "native", function() if paused() then draw_overlay() end end)

-- keys ------------------------------------------------------------------------------
local function key(name, k, fn)
  mp.add_forced_key_binding(k, "mviz-" .. name, fn, { repeatable = true })
end

-- any printable character: type it (and start a search if not typing yet)
mp.add_forced_key_binding("ANY_UNICODE", "mviz-type", function(e)
  if e.event == "up" then return end
  local c = e.key_text
  if not c or c == "" then return end
  if c == " " then space() else add(c) end
end, { complex = true })

key("space", "SPACE", space)
key("enter", "ENTER", function() if typing then submit() end end)
key("kp-enter", "KP_ENTER", function() if typing then submit() end end)
key("backspace", "BS", function()
  if not typing then return end
  text = text:gsub("[%z\1-\127\194-\244][\128-\191]*$", "")
  render()
end)
key("clear", "Ctrl+u", function() if typing then text = ""; render() end end)
key("delete-word", "Ctrl+w", function()
  if typing then text = text:gsub("%s*[^%s]*$", ""); render() end
end)
key("shuffle", "TAB", shuffle)
key("paste", "Ctrl+v", paste)
key("paste-alt", "Shift+INS", paste)
key("escape", "ESC", function()
  if typing then stop_typing()
  elseif mp.get_property_bool("fullscreen") then mp.set_property_bool("fullscreen", false) end
end)
key("volume-up", "UP", function() mp.command("no-osd add volume 5") end)
key("volume-down", "DOWN", function() mp.command("no-osd add volume -5") end)
key("fullscreen", "F11", function() mp.command("cycle fullscreen") end)
key("fullscreen-click", "MBTN_LEFT_DBL", function() mp.command("cycle fullscreen") end)
key("quit", "Ctrl+q", function() mp.command("quit") end)
key("close", "CLOSE_WIN", function() mp.command("quit") end)

-- shuffle moved on to the queued track (end of song, Tab, or the Next media key) ----
mp.register_event("file-loaded", function()
  if exists("shuffle") and mp.get_property_number("playlist-pos", 0) >= 1 then
    request("advance")
  end
end)

-- a new track that can't be played: go back to the last one that did ---------------
-- (mpv runs with --idle=yes so a failed load doesn't close the window). In shuffle,
-- try another random track instead, up to 3 times in a row.
local current, last_good
local failures = 0

mp.register_event("start-file", function() current = mp.get_property("path") end)
mp.register_event("playback-restart", function()
  last_good = current
  failures = 0
end)
mp.register_event("end-file", function(e)
  if e.reason ~= "error" then return end
  failures = failures + 1
  if exists("shuffle") and failures <= 3 then
    request("shuffle")
  elseif last_good and last_good ~= current then
    put("loadfail", "")
    mp.commandv("loadfile", last_good, "replace")
  else
    mp.commandv("quit", "2") -- nothing ever played: same as before, exit code 2
  end
end)

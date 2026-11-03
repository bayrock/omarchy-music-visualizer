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

local function render()
  local shown = text
  local cs = chars(text)
  if #cs > MAX_SHOWN then -- keep the end of a long query visible
    shown = "…" .. table.concat(cs, "", #cs - MAX_SHOWN + 2)
  end
  put("prompt.txt", ("root@%s:~# ./php2shell --search \"%s%s\"\n")
    :format(HOST, shown, cursor_on and CURSOR or " "))
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
  request("load", q)
end

-- Tab: skip to the queued track if shuffle has one ready, else (re)start shuffle
local function shuffle()
  if typing then return end
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

-- keys ------------------------------------------------------------------------------
local function key(name, k, fn)
  mp.add_forced_key_binding(k, "mviz-" .. name, fn, { repeatable = true })
end

-- any printable character: type it (and start a search if not typing yet)
mp.add_forced_key_binding("ANY_UNICODE", "mviz-type", function(e)
  if e.event == "up" then return end
  local c = e.key_text
  if not c or c == "" then return end
  if c == " " and not typing then
    mp.command("cycle pause")
  else
    add(c)
  end
end, { complex = true })

key("space", "SPACE", function()
  if typing then add(" ") else mp.command("cycle pause") end
end)
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

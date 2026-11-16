# Architecture

Barebones Godot 4 (2D) prototype. Windows export target. **Mouse only**: there is no player
object; the "player" is the view of the current scene, driven by mouse clicks on objects.

Open `Source/` as the Godot project (it contains `project.godot`).

## Folder layout

```
Source/
  project.godot, export_presets.cfg
  Architecture.md            <- this file; keep it current
  Assets/
    BackGrounds/             room backgrounds (hall.png, lab.png, the base screenshots *.jpg,
                             intro_classroom.png, intro_test.png)
    Menus/                   logo.png (colour), logo_dim.png (gray, shown before Enter)
    Scripts/                 reserved for asset-side scripts/tools (empty for now)
    Fonts/                   fonts (empty; Godot default font is used)
    Misc/                    door.png, turtle.png, panel_cover.png, ambient_placeholder.wav
  Scripts/                   all game scripts
  Rooms/                     one .tscn per room, plus Main.tscn
    Objects/                 reusable room objects (Door, Hotspot, BackArrow)
    Menus/                   menu scenes shown over rooms by Overlay (TerminalMenu.tscn)
tools/make_assets.py         regenerates the placeholder PNGs (outside the project)
tools/make_intro_assets.py   builds the intro images and sounds from the two photos
tools/make_ui_assets.py      generates Assets/Menus/back_arrow.png
tools/make_title_assets.py   builds the title logos + placeholder music from the source images
```

## Autoloads

| Name | Script | Role |
|------|--------|------|
| `RoomManager` | `Scripts/RoomManager.gd` | Room table and room swapping |
| `PowerGrid` | `Scripts/PowerGrid.gd` | State and rules of the soldering puzzle (survives room changes) |
| `Music` | `Scripts/Music.gd` | Looping background track on its own `Music` audio bus with a low-pass filter (muffled / clear) |
| `Overlay` | `Scripts/Overlay.gd` | Shows menu scenes (terminal, tablet...) over the current room |
| `Subsystems` | `Scripts/Subsystems.gd` | Status of the 5 repair subsystems and outpost power (see Repair minigames) |
| `Objectives` | `Scripts/Objectives.gd` | Scripted objective sequence + subsystem repairs (see Tablet) |
| `Tablet` | `Scripts/Tablet.gd` | Screen-fixed tablet icon, visited-room tracking and map markers (see Tablet) |
| `Story` | `Scripts/Story.gd` | On-screen message line and the sleepy / dream events (see Story events) |
| `Mission` | `Scripts/Mission.gd` | The sequence after the dream: Mission Control messages, lab story flags, debug stage jumps (see Post-dream sequence) |
| `DebugMenu` | `Scripts/DebugMenu.gd` | Shift+F12 debug menu (see Debug menu) |

## Rendering / pixel art

- Base viewport 640x360, window 1280x720, stretch `canvas_items`, integer scaling.
- Default texture filter is **Nearest** (project setting
  `rendering/textures/canvas_textures/default_texture_filter = 0`), plus snap-to-pixel for 2D.
  `Turtle` also sets `texture_filter = NEAREST` explicitly. No smoothing anywhere.

## Scene flow and room changing

- `Rooms/Main.tscn` is the persistent root (script `Main.gd`). It owns an empty `RoomHost` node.
  Its exported `start_room` picks the first room (`title`).
- `RoomManager.ROOMS` maps id -> scene path. `RoomManager.go_to("lab")` frees the current room
  scene and instantiates the new one into `RoomHost` (deferred, so the triggering click finishes).
- A room is a full scene (background + objects/menus), not just a swapped image.
- Rooms are rebuilt on every visit, so room nodes keep no state. Anything that must persist
  lives in an autoload (e.g. `PowerGrid`).

### Adding a room
1. Create `Rooms/MyRoom.tscn` (root `Node2D`, a background, objects).
2. Add `"myroom": "res://Rooms/MyRoom.tscn"` to `RoomManager.ROOMS`.
3. Link to it with a `Door` instance or a `NavButton`, setting `target_room = "myroom"`.

### Room transition (footsteps)

Every room change fades to black, swaps the room, plays `Assets/Misc/steps.wav` while it is black
and fades back in (`RoomManager._request`): `FADE_OUT` 0.15 s, `HOLD` 0.75 s black, `FADE_IN` 0.35 s,
about 1.25 s in total. Clicks are blocked while it runs. It is skipped when leaving or entering
`login`, `title`, `intro` or `dream` (`NO_TRANSITION`; they have their own fades), for the very first
room, and when `RoomManager.transitions = false`. The sound comes from your `steps.mp4`
(`tools/steps_original.mp4` -> `tools/make_steps_sound.py` trims it to the four footsteps and
normalizes the volume). Tune the three timing constants in `RoomManager.gd`.

## Mouse objects

- `Clickable` (`Scripts/Clickable.gd`, extends `Area2D`): left-click detection through
  `input_event`, hover brighten. Emits `clicked` and calls `_activate()`. Needs a
  `CollisionShape2D`. Subclasses that define `_ready()` must call `super._ready()`.
- `Door` (`Scripts/Door.gd`, extends `Clickable`): goes to `target_room`.
- `NavButton` (`Scripts/NavButton.gd`, extends `Button`): GUI button that goes to `target_room`.
- `PanelCover` (`Scripts/PanelCover.gd`, extends `Clickable`): desk hatch in the console room.
- GUI `Control` nodes consume clicks before `Area2D`s and `_unhandled_input`. Decorative
  `ColorRect`s must have `mouse_filter = 2` (Ignore) or they block clicks behind them.

## Rooms

| Id | Scene | Contents |
|----|-------|----------|
| `login` (start) | `Rooms/Login.tscn` | Fake registration / login, see "Fake login" below; goes to `title` |
| `title` | `Rooms/Title.tscn` | Starting screen, see "Title screen" below; Enter again goes to `intro` |
| `intro` | `Rooms/Intro.tscn` | Starting sequence after the title, see "Starting sequence" below; ends in `basefrontoutside` |
| `basefrontoutside` ... `hatch` | `Rooms/BaseFrontOutside.tscn` etc. | The moon base, see "Moon base rooms" below |
| `hall` | `Rooms/Hall.tscn` | Old demo, not linked from the base yet: doors to `console` and `lab` |
| `console` | `Rooms/Console.tscn` | Terminal (first screen), sticky note, desk hatch -> `wiring`, button to `hall` |
| `wiring` | `Rooms/Wiring.tscn` | Wiring panel (second screen), Reset, button back to `console` |
| `lab` | `Rooms/TurtleLab.tscn` | `Turtle`, `BlockEditor` (left panel), door to `hall` |

## Moon base rooms

Each room is a `Node2D` with a `Background` sprite (the screenshot, full resolution, scaled to
fit the 640x360 view, linear filter) plus `Hotspot` / `BackArrow` instances. Backgrounds are in
`Assets/BackGrounds/<id>.jpg`.

```
title -> basefrontoutside -> livingmodule -> livingmodulehall -> livingmodulehallroom
                              |  ^
        back arrow -> hatch <-+  +-- hatch -> livingmodule | biomodule
                       ^
        biomodule -----+  (back arrow)
```

| Room id | Forward hotspots | Back arrow goes to |
|---------|------------------|--------------------|
| `basefrontoutside` | -> `livingmodule` | none |
| `livingmodule` | -> `livingmodulehall` | `hatch` |
| `livingmodulehall` | -> `livingmodulehallroom` | `livingmodule` |
| `livingmodulehallroom` | none | `livingmodulehall` |
| `biomodule` | none | `hatch` |
| `hatch` | -> `livingmodule` (left), -> `biomodule` (right) | none |

The default hotspot positions are rough guesses made from the screenshots: **adjust them**.
Hall and hall-room back arrows go one step back instead of to the hatch (change `Target Room`
on the instance if you want them to go to `hatch`). Nothing leads to the hatch from outside yet.

### Hotspot (the click areas)
`Scripts/Hotspot.gd` (`class_name Hotspot`, `@tool`, extends `Area2D`), scene
`Rooms/Objects/Hotspot.tscn`. A left click calls `RoomManager.go_to(target_room)`.

To add or change one, in a room scene:
1. Instance `Rooms/Objects/Hotspot.tscn` (Ctrl+Shift+A or drag it in).
2. Drag the node in the 2D view, or set `Position`: this is the **center** of the area.
3. Set `Size` in the Inspector (script variables): width and height in pixels.
4. Set where it goes, either way:
   - **Target Scene**: drag the room's `.tscn` from the FileSystem dock into the slot (easiest,
     typos impossible), or
   - **Target Room**: type the room name. `RoomManager.go_to` looks in `ROOMS` first, then for a
     scene in `Rooms/` with that file name ignoring case (`commandcenter` finds
     `Rooms/commandcenter.tscn`), then treats it as a full `res://` path. A new room saved in
     `Rooms/` works with no code edit. Unknown names print an error in the Output panel.

You can also size a hotspot by scaling the node with the mouse; `Size` is the cleaner way
because the editor box then matches the click area exactly.

The editor draws every hotspot as a colored box labeled with its target, so you can see and
align it on the background. In game it is invisible, with a hand cursor and faint outline on
hover. Tick `Show In Game` on one hotspot to see its box while playing. The size is applied to
the child `Shape` (`resource_local_to_scene`), so each instance has its own size. Hotspots can
overlap, but then every overlapped one fires on a click, so avoid that.

### BackArrow
`Rooms/Objects/BackArrow.tscn` (script `Scripts/BackArrow.gd`) is a `CanvasLayer` (layer 10)
holding a Hotspot with a down-arrow icon (`Assets/Menus/back_arrow.png`, regenerate with
`tools/make_ui_assets.py` or replace it). Because it is on a CanvasLayer it is fixed to the
screen: it stays at the same place if a room ever gets a moving `Camera2D`, and it draws above
the room. The place (default bottom center, 320, 340) is set once, by the `Hotspot` child's
position inside `BackArrow.tscn`, so every room shares it. A CanvasLayer has no position of
its own, so it can't be dragged per room by accident. In each room only set `Target Room` or
`Target Scene` on the BackArrow instance.

### Adding a base room
1. Put the screenshot in `Assets/BackGrounds/`.
2. Duplicate a room scene, swap the `Background` texture and fix its scale
   (`640 / image width` if it is wide, `0.5` for 1280x719 images).
3. Save it in `Rooms/` (no registration needed, see Hotspot), then place hotspots and set targets.

## Overlay menus (hot buttons)

A **menu** is any scene whose root is a `Control`. It is shown full-screen over the current room
by the `Overlay` autoload (`Scripts/Overlay.gd`, a `CanvasLayer` on layer 20, above rooms and
the BackArrow). Menu scenes live in `Rooms/Menus/`.

- `Overlay.open(packed_scene)` / `Overlay.close()` / `Overlay.is_open()`; signals `opened`, `closed`.
- While a menu is open a dark dimmer swallows clicks, so the room's hotspots can't be pressed.
  Close with the menu's own button, **right click** on the dimmer, or **Esc**. Changing room
  closes the menu too.
- **Hot button = a Hotspot with `Menu Scene` set**: drag a menu `.tscn` into that slot in the
  Inspector. It wins over `Target Scene` / `Target Room`. The editor box is labeled `menu: <name>`.
- Menu scenes may keep state in `static var`s if it must survive being closed (the terminal does).
- To make a new menu (e.g. the tablet): new scene, root `Control`, build the UI, add a close
  button calling `Overlay.close()`, save in `Rooms/Menus/`, point a Hotspot at it. For an
  always-visible tablet button, put a Hotspot (with its icon) on a `CanvasLayer` like
  `BackArrow.tscn` does and set its `Menu Scene`.

## Command center terminal

`Rooms/Menus/TerminalMenu.tscn` + `Scripts/TerminalMenu.gd`, opened by the `TerminalHotspot`
over the middle monitor in `Rooms/commandcenter.tscn` (it also has a BackArrow to
`livingmodulehall`). Left: a green-on-black CADEMU monitor console. Right: a yellow sticky
note with the reminder text.

- **Boot log** types itself on the first open: banner, then diagnostic lines with real UTC
  timestamps `[HH:MM:SS.mmm]`, a memory-test progress bar, retried network probes, the
  action-required lines and the `CADEMU\MONITOR>` prompt. The subsystem status list is
  deliberately NOT shown at boot: the player must type `systemscfg /statusreport` to see it. Click the screen to
  skip. Transcript and unfinished output persist if you close and re-open the terminal.
- **Typing is the one place that needs the keyboard.** Clicking a command on the sticky note
  copies it into the prompt, so only Enter is needed. Up/Down arrows recall history.
- Commands (case-insensitive): `systemscfg /statusreport` (progress bar, then a table of the five
  subsystems with host, uptime, self-test 0 PASS / 5 FAIL, fault code), `data_diver_protocol.exe`
  (cache scan, remote unreachable, table of submitted data packets), plus `help`, `dir`, `ver`,
  `date`, `whoami`, `cls`, `exit`. Anything else gives the Windows-style "not recognized" error.
- Output colors are picked from the text (`[ERR`/OFFLINE red, `[WARN`/`[NET` amber, OK green).
- All text lives in constants at the top of `TerminalMenu.gd` and in `_queue_boot()`,
  `_cmd_systemscfg()`, `_cmd_data_diver()`. `DIVER_ROWS` is placeholder data to replace.
  `SUBSYSTEMS` is static for now; hook it to game state (e.g. `PowerGrid`) later.
- Output is a queue of line dicts printed by `_process` with per-line delays (`_say`, `_bar`).
  Add a command by adding a `match` branch in `_submit()` that queues lines with `_say`.

## Starting sequence (intro)

`Rooms/Intro.tscn` + `Scripts/IntroSequence.gd` (+ `Scripts/HelmetView.gd`), played after the
title screen and ending in `basefrontoutside`. The whole scene is built in code and driven by one
coroutine, `_play()`; read it top to bottom, each numbered block is one beat:

1. Black, "A memory grasps into your head...". The music goes muffled for the whole flashback.
2. Fade into a white flash, then the classroom photo (slow zoom). The instructor ("????") types
   his line and the box vanishes mid-sentence: the sudden cut to black.
3. The photo of the test appears on the left; the question panel on the right (mouse). **A and B
   are refused** (the panel shakes, "that is not what you answered"); only **C** continues.
4. Green flash on C, back to the classroom photo, three subtitle chunks of the instructor's
   lecture.
5. The photo flickers and dissolves into static (random noise texture + looping static sound).
6. Static resolves into the helmet cam (procedural placeholder landscape, vignette, `[REC]`
   clock). Music clears up. Mission Control V.O., the camera nods, "...Welcome to the Moon.",
   the HUD lines boot one by one with a beep, then the amber objective line blinks.
7. Fade to black; `_leave()` switches to `NEXT_ROOM` and a black cover on its own CanvasLayer
   fades out over the new room.

- Subtitles are typed by `_say(speaker, text, color, cut := false)`. Click while typing to finish
  the line. The **Skip >>** button calls `_leave()` immediately.
- Edit the story text in `_play()` and the constants at the top (`QUESTION`, `OPTIONS`,
  `HUD_LINES`, `OBJECTIVE`, `NEXT_ROOM`, colors, `CHAR_TIME`).
- Images: `Assets/BackGrounds/intro_classroom.png`, `intro_test.png` (grayscale, 1400 px max).
  Sounds: `Assets/Misc/beep.wav`, `static.wav` (generated placeholders).
  `tools/make_intro_assets.py <classroom> <test>` rebuilds them.
- The helmet landscape is placeholder art drawn by `HelmetView`; replace it with a real picture
  by swapping that node for a `Sprite2D` in `_build()`.
- The objective text is only displayed; nothing stores it yet. A future `Objective` autoload
  (read by the tablet) could be set at the end of the HUD boot.

## Dream sequence

`Rooms/Dream.tscn` + `Scripts/DreamSequence.gd` (a room scene, built in code like the intro). It is
started from the bed in the hall room (`LivingModuleHallRoom`): a Hotspot over the bed with its
**Target Scene** set to `Rooms/Dream.tscn`. It is locked until the player is sleepy (see "Story events").

Flow: black + "Suddenly. A new memory emerges..." (music goes muffled) > the forest behind the
mesh (`Assets/BackGrounds/dream_forest.jpg`) fades in and "Then, you try to remember what you
did..." types in slowly while shaking > crossfade to the tree seen from the floor
(`dream_tree.jpg`), held 3.5 s, then tinted fully red over 5 s (with the `hum.wav` drone) >
"Now you remember." / "You hate earth" in white on the red > "Don't bring me back" starts typing
and is cut off after 13 characters while everything fades into `RETURN_ROOM`
(`livingmodulehallroom`). All text, typing speeds and timings are constants at the top of the
script. Skip button (bottom right) leaves at once. With `Subsystems.reduced_motion` the text does
not shake and the photos do not drift. The tablet icon is hidden during it (`Tablet.HIDDEN_ROOMS`)
and it sets the `dream_seen` objective flag when it ends.

## Story events (sleepy, then the dream)

`Story` autoload (`Scripts/Story.gd`, a `CanvasLayer` at layer 22). `Story.say("text")` shows a short
message in a box near the bottom of the screen (0.5 s in, 3.5 s hold, 0.8 s out).

1. The player repairs the fifth subsystem (`Subsystems.outpost_powered`). When its menu has closed,
   plus 0.8 s, `Story.start_sleepy()` runs: it sets the Objectives flag `sleepy`, shows "You are
   sleepy. Go to sleep.", and puts a **yellow dot** on the map zone of the player's room
   (`Story.SLEEP_ROOM` = `livingmodulehallroom`). The tablet's objective list then adds "Go to sleep
   in your room".
2. The bed Hotspot in `LivingModuleHallRoom.tscn` has **Required Flag = `sleepy`** and **Locked
   Message = "You are not tired."**, so clicking the bed does nothing but show that message until
   the flag is set. Then it starts `Rooms/Dream.tscn` (which also bounces back if `sleepy` is not
   set).
3. After the dream (`dream_seen`) the yellow dot is removed, `sleepy` is cleared again (the bed is
   locked again) and, once the player is back in the hall room, `Story.dream_finished` is emitted.
   **That signal starts the next sequence** (`Mission`, see "Post-dream sequence").

Generic pieces: `Hotspot` has **Required Flag** / **Locked Message** exports (any Objectives flag can
gate a click). `Tablet.set_marker(room_id, color)` / `clear_marker(room_id)` put a pulsing colored
dot with a ring on that room's `MapRoom` zone and light it even if undiscovered (the red "you are
here" dot wins when the player is in that room). Debug terminal commands: `debug_sleepy` (start the
event now) and `debug_story_reset` (clear sleepy / dream progress).

## Fake login (prototype, removable)

`Rooms/Login.tscn` + `Scripts/LoginScreen.gd` + `Scripts/FakeAccounts.gd`. The first screen
(`Main.gd` `start_room = "login"`), shown before the CADEMU title. Black background, a panel with
**Log in** / **Register** tabs (username, password, confirm password), "Continue as guest" and
"Clear saved accounts". Submitting shows "Contacting CADEMU personnel server..." for about a
second, then either an error (`[X]`: unknown username or wrong password, username taken, passwords
do not match, username must be 3-16 letters/numbers/_, password 4-32 characters) or "ACCESS
GRANTED. Welcome, Cadet NAME (ID CDT-0001)", a fade to black and `title` (which also starts on
black, with the music muffled the whole time).

- **Database:** `FakeAccounts` (static, no autoload) keeps accounts in `user://fake_accounts.json`
  (the game's user/temporary data folder; on Windows `%APPDATA%\Godot\app_userdata\<project>\`).
  Passwords are stored salted + SHA-256 hashed. It is NOT real security. `PERSIST = false` keeps
  accounts in memory only (gone when the game closes). `FakeAccounts.wipe()` / the "Clear saved
  accounts" button deletes them.
- **After login:** `FakeAccounts.current_user` and `current_id` say who is playing (guest =
  `Guest` / `CDT-GUEST`); nothing else in the game uses them yet.
- **Turn off:** set `FakeAccounts.ENABLED = false`; the login screen then skips straight to
  `title`. Or set `Main.gd` `start_room` to `"title"`.
- **Remove completely:** delete `Rooms/Login.tscn`, `Scripts/LoginScreen.gd`,
  `Scripts/FakeAccounts.gd`, set `Main.gd` `start_room` back to `"title"` (leftover `"login"`
  entries in `Main.gd` and `Tablet.HIDDEN_ROOMS` are harmless), and delete the user data file.

## Title screen

`Rooms/Title.tscn` + `Scripts/TitleScreen.gd`. Starting screen with a three-state flow:

1. **WAITING**: black background, dim gray logo (`Assets/Menus/logo_dim.png`) centered,
   blinking "Press Enter", music muffled for the whole step (`Music.set_muffled(true)`: 24 dB/oct low-pass at 280 Hz, -8 dB).
2. **Enter (or left click)** -> **FLASHING**: the screen goes instantly white. Under it the logo
   swaps to the colour logo (`Assets/Menus/logo.png`), the starfield appears as a fast warp
   burst and the music un-muffles over 2 s. The white fades out in 0.45 s while the stars
   slow down to cruising speed over 3 s.
3. **READY**: stays on the starfield with the colour logo. Enter / click again calls
   `RoomManager.go_to(NEXT_ROOM)` (`intro`). Change `NEXT_ROOM` when a real menu exists.

Tunables are constants at the top of `TitleScreen.gd` (`FLASH_FADE`, `WARP_SPEED`,
`CRUISE_SPEED`, `WARP_SETTLE`, `MUSIC_FADE`).

- `Starfield` (`Scripts/Starfield.gd`): 110 pixel stars in depth layers (deeper = faster and
  dimmer) flying right to left. `speed` (px/s) can be tweened from outside; streak length
  grows with speed. Reusable in any room.
- `Music` (autoload): lives across rooms so the track doesn't restart on room changes. The track
  is `Assets/Misc/ambient_placeholder.wav` (generated placeholder, 8 s loop). Replace the file
  or edit `TRACK` in `Music.gd`. Loop is done by replaying on `finished`. The muffling is an
  `AudioEffectLowPassFilter` on the `Music` bus, so it works with any track. Note a track with
  little high-frequency content will sound only slightly muffled. `Music` starts muffled (so nothing
  clear plays before the title loads); `Main.gd` opens it up if `start_room` isn't `title`. The
  filter is 24 dB/oct and the fade moves the cutoff in log frequency so it is audible for the
  whole fade; tune `MUFFLED_HZ` / `MUFFLED_DB` in `Music.gd`.
- Enter is the `ui_accept` input action, so Space also works. This is the one place that uses
  the keyboard; the click alternative keeps it mouse-playable.
- `tools/make_title_assets.py <dim.jpg> <color.jpg>` rebuilds both logo PNGs (background
  removed, both cropped and scaled to 400 px wide, black subtitle text turned white so it is
  visible on dark) and the placeholder wav.

## Soldering puzzle (console + wiring)

### Story setup
The terminal says power rebalancing succeeded but `monitorlegacy01` is missing 30 watts.
The sticky note says the desk panel is unscrewed: click the cover to take it off, click the
opening to reach the wiring panel.

### Rules (all in `PowerGrid.gd`, numbers are constants at the top)
- Sources on the left supply watts (`SOURCES`: V55=55, V67=67, V22=22, V86=86, V65=65).
- Devices on the right need watts (`DEVICES`: monitorlegacy01 85, oxygenmonitor 60,
  comms 60, dont-disconnect 20).
- Wires, cut pieces and **soldered** splices form circuits. A device gets the sum of all
  sources in its circuit. Twisted but unsoldered splices do not conduct.
- `CRITICAL` devices (`dont-disconnect`) halt the system when they drop below their need:
  `failed = true`, the panel locks until Reset (wiring room) or Restart system (console).
- Solved when every device meets its need (`solved = true`, console prints
  "all systems nominal").
- Every power change on a device writes a line to `PowerGrid.log_lines`, which the console
  terminal prints (last 18 lines + `user-console:~$`).

Default solution: cut yellow (V55) and pink (V86), splice V86 to the monitorlegacy01 piece
(86 >= 85), then splice the loose orange V65 to the oxygenmonitor piece (65 >= 60).
V55 alone can't run oxygenmonitor (55 < 60), and cutting the dark red V22 wire halts the system.

### Western Union splice, step by step (mouse only)
Click a tool in the tray to hold it, click it again or right click to put it down (hand).

| Step | Tool | Click on | Result |
|------|------|----------|--------|
| 1. Cut | Scissors | a wire | Splits it into two pieces with insulated free ends |
| 2. Strip | Scissors | a free end | Insulation off, end shows copper |
| 3. Cross | Hand | two stripped ends (from different pieces) | Ends overlap at their midpoint: a splice |
| 4. Twist | Hand | the splice, 6 times | 3 wraps per side, alternating (`WRAPS_NEEDED`) |
| 5. Heat | Solder iron | the twisted splice | Joint glows; cools over `HEAT_SECONDS` |
| 6. Tin | Tin | the hot splice | Soldered, now conducts. Cold joint = tin refuses to flow |
| Undo | Scissors | a splice | Cuts it apart, ends go back to stripped |

### Data model
- `segments[id] = {color, p: [p0, c0, c1, p1] (cubic bezier), ends: [end_id, end_id]}`
- `ends[id] = {seg, idx (0 = p0, 1 = p1), kind: source|device|free, name, state}` where
  state is `terminal`, `insulated`, `stripped` or `spliced`. End ids survive cuts, so splices
  stay valid when a piece is cut again.
- `splices[id] = {a, b, pos, wraps, heat, soldered}`
- Cutting uses de Casteljau splitting (`split`, `sub`) with a 4 px gap. Splicing moves each
  end (and its neighbouring control point) to the joint.
- `WiringPanel.gd` only draws state and maps clicks to `PowerGrid` actions; each action
  returns the message shown at the top of the panel.

### Changing the puzzle
Edit `SOURCES`, `DEVICES`, `CRITICAL`, the `*_POS` tables and `_start_wires()` in
`PowerGrid.gd`. The starting "missing N watts" line is generated from those numbers.
The empty fifth slot in the device box has no device yet.

## Repair minigames (ERR-001 .. ERR-005)

Five subsystem repair games, each a menu scene opened through `Overlay` (Hotspot > **Menu Scene**).
I did not place any hotspots; attach these scenes (all in `Rooms/Menus/`) where you want them:

| Scene | Subsystem | Minigame script |
|---|---|---|
| `RadiationShieldMenu.tscn` | ERR-001 Radiation shield | `Minigames/SolarFlareMinigame.gd` |
| `OxygenMenu.tscn` | ERR-002 Oxygen management | `Minigames/OxygenMinigame.gd` |
| `PowerCollectionMenu.tscn` | ERR-003 Power collection | `Minigames/BatteryMinigame.gd` |
| `VitalSignsMenu.tscn` | ERR-004 Crew vital signs | `Minigames/HeartbeatMinigame.gd` |
| `AntennaMenu.tscn` | ERR-005 External terminal network | `Minigames/AntennaMinigame.gd` |
| `StatusPanelMenu.tscn` | (all) live status + power bus | `StatusPanelMenu.gd` |

The soldering puzzle (`PowerGrid`, `Wiring`, `Console`) is untouched and not linked to these.

**`Subsystems` autoload** (`Scripts/Subsystems.gd`): holds the 5 subsystems (all OFFLINE at start)
and outpost power. `complete("ERR-00X")` flips one ONLINE (+20% power); the fifth sets `powered`
and emits `outpost_powered`. `rows()` feeds the terminal report and status panel. Flags:
`debug_mode` (lets finished games be replayed), `reduced_motion`. Debug helpers:
`debug_complete(id)`, `debug_reset_all()`, `debug_set_progress(n)`.

**Hidden terminal commands** (not on the sticky note): `debug_complete ERR-00X`, `debug_reset`,
`debug_progress N`, `debug_mode`. `systemscfg /statusreport` now reads live state.

**Shared shell** (`Minigames/MinigameBase.gd`): title, power bus (`PowerBus.gd`), live win checklist,
meters (`MeterBar.gd`), toast messages, Retry-step and Exit buttons, reduced-motion checkbox,
pause on window focus loss, win pulse (2 s) / power-up sequence (5 s on the fifth repair), and a
drawing/input canvas (`GameCanvas.gd`, 434x246). A game overrides `_configure`, `_init_game`,
`_tick`, `_draw_game`, `_game_input`, `_retry_step` and calls `win()` when done.
Opening a game whose subsystem is already ONLINE shows a notice (unless `debug_mode`).

**Feedback rules:** state is never color-only: green circle = good, amber triangle = warning,
red square-X = failing, plus [OK]/[!]/[X] toast prefixes and sounds. Wrong actions cost time or
quality and never fully reset a game; "soft fail" resets only the current step/wave.

**Games (tuning constants are at the top of each script; all are guesses):**
- ERR-002 Oxygen: hold on 4 clogged filters to remove them, then drag replacements in order into
  the highlighted slot (shape + color show which). Wrong filter = faster air drain for 2 s.
  Win: air above 50% after scrubbers recover it.
- ERR-003 Battery: 4x3 cells, 3 meteorite waves with a 1.2 s warning; click a warned cell to
  shield it, a damaged cell to patch it. Win: all waves done, all patched, charge above 60%.
- ERR-001 Radiation: 5 shield segments, flares warned 1.4 s ahead; click the segment to shield
  (2 s, then cooldown). Survive 30 s with radiation below 40%.
- ERR-004 Heartbeat: 3 drifting heart rates, click -/+ to hold all in 60-85 BPM for 8 s.
- ERR-005 Antenna: hold the mouse and sweep the map to a drifting hidden peak; hold signal
  above 80% for 6 s.

**"Error solved" sound:** `Subsystems.complete()` plays `Assets/Misc/bling.wav` once when a subsystem goes
ONLINE (a subsystem that is already ONLINE does not replay it; it works for the terminal
`debug_complete` too, but not for `debug_progress` / `debug_reset`). It is made from your
`bling.mp4` (`tools/bling_original.mp4` -> `tools/make_bling_sound.py`). The win itself no longer
plays the beep.

`tools/make_minigame_assets.py` generates `Assets/Misc/hum.wav` (power-up hum, placeholder).

## Tablet, objectives and map

A small tablet icon sits at the bottom right of every room except the title and intro
(`Tablet` autoload, a `CanvasLayer` at layer 9, built in code). Clicking it opens
`Rooms/Menus/TabletMenu.tscn` through `Overlay` (click the icon again or right click to close).
An amber dot on the icon means the objectives changed since the tablet was last opened.

**Tablet screen** (`Scripts/TabletMenu.gd`): current objective, notes for the room you are in,
the objective list, and a round **MAP** button that switches to the map view (Back returns).

**Objectives** (`Scripts/Objectives.gd`): an ordered `STORY` list; a step is shown only after the
previous one is done, and a step is done when its flag was set with `Objectives.flag("name")`.
After the story steps, one "Repair ERR-00X" objective per subsystem appears (live from
`Subsystems`), then "Outpost powered". Flags set so far: `console_opened` (terminal opens),
`status_report` (player runs `systemscfg /statusreport`, which is what reveals the repair list).
To add a step, add an entry to `STORY` and call `Objectives.flag(...)` where the event happens.

**Map** (`Rooms/Menus/MapLayout.tscn`): the map is NOT derived from scenes (many scenes are not
rooms). It is ONE picture plus zones you place by hand, Among Us style.
- The picture is the `MapImage` TextureRect: `Assets/Menus/base_map.png`, your hand-made map
  (`base_map_original.png`) restyled by `tools/make_base_map.py` (dark tablet look, labels removed,
  cropped). To use other art, replace that PNG and set the `MapLayout` node size to the picture size.
  Zones are placed in picture pixels; the tablet enlarges the map view and scales the layout to fit.
- Each **zone** is a `MapRoom` node (`Scripts/MapRoom.gd`, `@tool`) dragged and resized over an area
  of the picture. In the editor it shows as a tinted box with its name and a red crosshair (the dot
  position). To add one: duplicate a zone and set in the Inspector:
  - **Room Id**: RoomManager name (scene file name, any case). **Also In Zone**: more room ids
    that share this zone (closeups, side rooms): the dot shows here for them too.
  - **Display Name** and **Description**: the tablet's text for the room (fill in whenever).
  - **Dot At**: where the red dot sits inside the zone, (0,0) top-left to (1,1) bottom-right.
  - **Always Lit**, **Undim When Visited** (room ids that un-dim it; empty = its own rooms) and
    **Undim Flag** (also un-dims when that `Objectives` flag is set): when the zone stops being dim.
- Dimming: a zone that is not lit draws a dark 78% overlay over its rectangle. The current zone
  gets a white border and a pulsing red dot. Zones are rectangles.
- Rooms with no zone are ignored (the tablet says "No map data" and there is no dot).
- `Tablet` records visited rooms from `RoomManager.room_changed` (lower case, file name only).
- The map holds 20 zones, one per room of the picture. Hatch, Hall, Your room and Living module are
  named (`hatch`, `livingmodulehall`, `livingmodulehallroom`, `livingmodule`); the other 16 are
  `Zone 5` to `Zone 20` with an empty Room Id (they stay dark) until you fill them in.
- Debug terminal commands: `debug_map` (toggle: light every zone), `debug_objectives` (complete
  story steps so the repair objectives show).

## Turtle system

`Turtle` (`Scripts/Turtle.gd`, `Node2D`). Keep it at the room origin; it draws its own trail
lines and its sprite (`Assets/Misc/turtle.png`, drawn 2x) in room coordinates.

- State: `pos`, `heading` (degrees, 0 = up, clockwise positive), `home`.
- API: `run(program)` (awaitable, emits `finished`), `stop()`, `reset()` (clears trail, returns home).
- Execution is a coroutine stepping once per frame (`speed` px/s, `turn_speed` deg/s), so
  `stop()`/`reset()` take effect immediately and nothing blocks.

### Program format
A program is an `Array` of command dictionaries:

```gdscript
{"op": "forward", "n": 50}                       # move n pixels, draws a line
{"op": "left",    "n": 90}                       # turn counter-clockwise n degrees
{"op": "right",   "n": 90}                       # turn clockwise n degrees
{"op": "repeat",  "n": 4, "body": [ ...cmds ]}  # run body n times; nests freely
```

Square: `[{"op":"repeat","n":4,"body":[{"op":"forward","n":80},{"op":"right","n":90}]}]`.
The editor also adds an `"id"` key per command; the turtle ignores it.
Because programs are plain data, other systems can build and run them without any UI.

### Block editor (mouse only)
`BlockEditor` (`Scripts/BlockEditor.gd`, `PanelContainer`) builds its UI in code. A room only
needs to add the node and set `turtle`.

- Palette buttons append a block to the active container (root, or the innermost open Repeat).
- `Repeat` opens a container (marked `<`); new blocks go inside until `End Repeat`.
- Each row has `-` / `+` (change value by that block's step, clamped) and `x` (delete).
- `Run`, `Stop`, `Clear` (empties program), `Wipe` (resets turtle and trail).
- Deleting a block closes all open Repeats (active container falls back to root).

## Export (Windows)

`export_presets.cfg` has a "Windows Desktop" preset (x86_64, embedded PCK) writing to
`../Build/TurtleRooms.exe`. Install Godot export templates (Editor > Manage Export Templates)
first, then Project > Export.

## Export (Web / HTML5)

The project already uses the GL Compatibility renderer, which is what Web needs. `export_presets.cfg`
has a **Web** preset: single-threaded (`variant/thread_support=false`, so it needs no special
server headers and works on itch.io and any plain static host), adaptive canvas resize, canvas
focus on start (needed so typing in the login/terminal works), `*.md` excluded, exported to
`../../TurtleExports/web/index.html` (next to `TurtleRooms/`).

**Export:** Editor > Manage Export Templates (install the 4.7 templates once) > Project > Export >
**Web** > Export Project. Command line:
`godot --headless --path Source --export-release "Web" ../../TurtleExports/web/index.html`.

**Test locally:** browsers refuse to run it from `file://`. Run `python tools/serve_web.py` (serves
the web export folder at http://localhost:8060), or use the editor's one-click Remote Debug > Run in
Browser. **Publish:** upload the *contents* of the export folder (index.html, .js, .wasm, .pck,
icons...) to any static host; for itch.io zip them with `index.html` at the zip root and tick
"This file will be played in the browser". Total download is roughly 10 MB.

**What was changed for the browser:**
- `Scripts/MonoFont.gd`: browsers have no system fonts, so the web build uses the bundled
  `Assets/Fonts/DejaVuSansMono.ttf` (license text next to it) for the terminal and helmet HUD;
  desktop keeps the system monospace font (`ALWAYS_BUNDLED = true` forces the bundled one).
- No `Crypto` (the intro's static noise is a prebuilt texture pool; the fake-login salt uses
  `RandomNumberGenerator`).
- `project.godot` web-only overrides: windowed mode (no forced fullscreen at start) and
  `fractional` stretch scale (the page's canvas can be any size; `integer` would leave tiny
  pictures in small windows).

**Browser notes:** audio only starts after the first click or key press (browser autoplay rule), so
the music begins when the player first interacts with the login screen. Fake-login accounts
(`user://`) live in the browser's IndexedDB for that site: they persist per browser and site, and
"Clear saved accounts" or clearing site data removes them. Right-click is used to close menus: if a
browser shows its own context menu over the game, tell me and I will block it with a custom HTML
shell.

## Post-dream sequence (samples and the laboratory)

Autoload `Mission` (`Scripts/Mission.gd`, CanvasLayer 23). Everything is driven by Objectives flags,
the tablet's objective list (`Objectives.POST`) and the yellow map dot follow them.

| Step | What happens | Flag set |
|---|---|---|
| Waking up | `Story.dream_finished` -> 4 s of quiet (`WAKE_DELAY`) -> Mission Control message box | `mc_briefing` |
| Retrieve | Fridge in `labinside2left` (its old empty Hotspot3 now opens `SampleStorageMenu`). Read labels, check survey numbers, condition, open; take the container of the latest survey (SRV-0412). One older container has a torn label, Sample 04 is in the database twice. | `samples_retrieved` |
| Deliver | Bench in `microscopecloseup` (new `BenchHotspot`, opens `LabBenchMenu`): place the container on the table | `samples_delivered` |
| Prepare | per specimen: place, cut a thin section (stop the blade in the green zone), mount, secure, load | `samples_prepared` |
| Examine | microscope: magnification, illumination, focus, move (arrows or drag), "Capture image" on the structures. Samples: 01 basalt, 02 anorthosite, 03 regolith, 04 unknown (takes longer, needs 2 images, same structures stay visible). Optional: "Wipe lens" | `samples_examined` |
| Report | Lab PC (keyboard in `labinside2leftinto1`, new `ComputerHotspot`, opens `LabComputerMenu`): pick a classification for each sample, "Run database match" (Sample 04: ANALYSIS INCONSISTENCY / UNKNOWN ORGANIC COMPOUND, a flash of REFERENCE DATABASE: EARTH), submit. The first upload attempt fails once (retry). | `report_submitted` |
| Response | 3 s later Mission Control asks to repeat Sample 04 | `recheck_requested` |
| Recheck | bench again, Sample 04 only; it now looks like ordinary rock | `sample4_rechecked` |
| Second upload | Lab PC: upload the second result; Mission Control: "Second examination received..." | `second_uploaded` (`Mission.sequence_complete`) |

Files: `Scripts/Lab/` (`LabUI` building helpers, `LabMenu` base with right-click close,
`SampleStorageMenu`, `LabBenchMenu`, `LabComputerMenu`, `SpecimenView` = the procedural microscope
picture) and `Rooms/Menus/{SampleStorageMenu,LabBenchMenu,LabComputerMenu}.tscn`.
Per-specimen state lives in `Mission` (`prepared`, `examined`, `captures`, `classified`, `processed`).
Message texts, delays and the specimen list are constants at the top of `Mission.gd`; the text of
the lab menus is in their scripts. The map dot targets the rooms `ROOM_STORAGE`, `ROOM_BENCH`,
`ROOM_COMPUTER` (Mission.gd): name those zones in `MapLayout.tscn` (room_id) to see the dots.

**Not built yet** (the "later missions" part of the sample analysis notes): the teammate's inconsistent
memory, PERSONAL_ARCHIVE, the exterior camera forest, Earth communication, the interrupted recording,
the window reflection, and the optional chores calibration, label matching and equipment maintenance.
(Lens cleaning, returning specimens to storage and the failed first upload are in.)

## Debug menu (Shift+F12)

Autoload `DebugMenu` (`Scripts/DebugMenu.gd`, layer 40, above everything). Shift+F12 opens/closes it.
- **Jump to progress**: sets every flag and state for that point (`Mission.STAGES`; repairs, sleepy,
  dream, briefing, each lab step, report, recheck, end). Jumping back clears what comes after.
- **Room**: pick any scene in `Rooms/` and go there. **Story flags**: tick/untick individual flags.
- **Tools**: reveal the whole map, show hotspot boxes in game, room transitions on/off, complete or
  reset repairs, open the tablet, test messages.
To ship without it set `ENABLED = false` in `DebugMenu.gd` (or remove the autoload).

## Known limits / next ideas

- Turtle: no pen up/down, backward, colors, or variable values yet.
- Soldering: only end-to-end (inline) splices, no T-splices; sources feeding several devices
  aren't split between them; heat only decays, no overheating.
- No transitions or audio. Console and wiring screens are drawn with ColorRects / `_draw`;
  swap in PNGs from `Assets/BackGrounds` when real art exists.
- Written without access to a Godot binary; first open in the editor may surface small fixes.

# Feedback!

An educational simulation about positive and negative feedback for middle-school biology, built from
`feedback+gdd_v0.1.md` (GDD v0.1). Godot 4.7, GDScript, no plugins, no external assets: every picture is
drawn in code and every sound is synthesised at start-up.

Students watch two short demonstrations (a noisy classroom, then the same ideas as abstract machines) and
then run their own experiments on blood clotting (positive feedback) and blood glucose (negative feedback),
reading the results from a graph that replays in step with the animation.

## Features

### Application
- [x] Main menu with the four modules, grouped as Watch (demonstrations) and Experiment (interactive); nothing is locked
- [x] Top bar on every screen: Menu, Next Module, Sound On/Off, Volume (0 to 5), Motion Full/Reduced
- [x] One shared graph component and one shared timeline recorder used by all four modules
- [x] Fixed model time steps and seeded random numbers (same settings give the same run)
- [x] Procedural audio: four student voices, teacher voice, BIP, BOOP, boost, pop; capped mix
- [x] Captions or symbols for every meaningful sound (speech marks, WHOMP!, BIP!/BOOP!/BOOST!, graph marks)
- [x] Keyboard: every button reachable with Tab; Tab past the end, Shift+Tab before the start, or Escape hands focus back to the host page
- [x] Web export, single-threaded, GL Compatibility, `index.html` at the root
- [x] Class setting in the address: `?module=classroom|abstract|clotting|glucose`
- [ ] Text-size option (not built)
- [ ] Layout that reflows for phones or very short frames (not built: the 1180 x 500 layout scales down as a whole)

### 1. Watch: Classroom Chatter
- [x] 15 procedurally drawn students with varied skin tones (12), hair colours and styles (8) and proportions, in navy uniform shirts; two fixed teacher characters; looks are generated separately from behaviour
- [x] Activity spreads between neighbouring students; head, mouth and arm movement follow each student's activity
- [x] Teacher answers at the threshold with three WHOMP! notes; the noise falls in three steps to zero
- [x] After three cycles a second teacher arrives, the teacher is distracted, and the noise climbs to its ceiling
- [x] Live graph with the teacher's limit line; closing message from the GDD
- [x] Play, Pause, Replay, Skip Ahead

### 2. Watch: Abstract Feedback
- [x] Negative feedback: sensing delay, then a corrector pushes back (BIP! down, BOOP! up); overshoot comes from the delay, not from a drawn sine wave
- [x] Positive feedback: each boost is sized by how far the quantity has already moved; slows and stops at a marked limit
- [x] A third short part repeats positive feedback with a downward nudge
- [x] Play, Pause, Replay, Skip Part

### 3. Experiment: Blood Clotting
- [x] Controls: Wound Size, Platelet Supply, Recruit Signals (three values each); Start/Pause, Reset, View Results
- [x] Particle model: flow, first-contact adhesion, signal release, signal-driven recruitment, stacking, coverage, finite supply
- [x] Results: graph of attached platelets with four annotated events, a one-line summary, synchronised replay, click-the-graph scrubbing
- [x] Reflection prompts with optional sentence starters (no typing)

### 4. Experiment: Blood Glucose
- [x] Disturbances: Eat a Meal, Exercise, Fasting On/Off; Advanced panel: Insulin Response and Glucagon Response, Normal/Reduced
- [x] Model: glucose, insulin, glucagon, liver glycogen, food input, tissue use, liver output and storage
- [x] Picture: bloodstream, pancreas with two hormone gauges, liver with a glycogen store, body cells, food, a glucose meter with the target range
- [x] Results: glucose graph with target band and events; optional insulin, glucagon and glycogen lines (off by default); synchronised replay
- [x] Reflection prompts with optional sentence starters

## Run

Open the folder in Godot 4.7 and press Play, or from PowerShell:

```powershell
$godot = "C:\Users\seanm\Nextcloud2\Gamedev\Godot_v4.7.2-stable_win64_console.exe"
& $godot --path .
```

## Test

```powershell
& $godot --headless --path . --editor --quit-after 250      # import; expect no SCRIPT ERROR
& $godot --headless --path . --script tests/test_models.gd  # the four models (58 checks)
& $godot --headless --path . --script tests/test_app.gd     # the running app, every control (96 checks)
```

Each test prints `<name>: N/N passed (expected N checks) -> PASS` and exits 0, or lists failures and exits 1.
A run that stops early cannot pass, because the number of checks is compared with the expected total.

Developer tools (not tests). Save their output **outside** this folder, or Godot will import and export it:

```powershell
& $godot --path . --resolution 1180x500 --script tests/shot.gd -- "$env:TEMP\feedback-shots"          # screenshots of every module
& $godot --path . --resolution 1180x500 --script tests/shot.gd -- "$env:TEMP\feedback-shots" reduced  # same, reduced motion
& $godot --headless --path . --script tests/dump_audio.gd -- "$env:TEMP\feedback-audio"               # every sound as a .wav
```

## Export and browser check

Needs Godot's standard 4.7.2 export templates installed.

```powershell
& $godot --headless --path . --export-release "Web" ..\exports\feedback-sim\index.html

# Stage a throwaway web root OUTSIDE the project: the export as game\, plus the iframe harness
$root = "$env:TEMP\feedback-web"
New-Item -ItemType Directory -Force "$root\game" | Out-Null
Copy-Item ..\exports\feedback-sim\* "$root\game\" -Force
Copy-Item tests\web\harness.html "$root\" -Force

# In a second terminal (check the port is free first)
python -m http.server 8831 --bind 127.0.0.1 --directory $root

# Back in the first terminal
$env:NODE_PATH = "C:\Users\seanm\Nextcloud2\Website\game-sim-server\node_modules"
$env:PORT = "8831"
node tests\web\web_check.js "$env:TEMP\feedback-shots"          # installed Chrome, headless (47 checks, about 5 minutes)
node tests\web\web_check.js "$env:TEMP\feedback-shots" headed   # a visible Chrome window
node tests\web\axe_check.js                                     # axe-core on the HTML shell
```

`$env:QUICK = "1"` shortens the 60-second no-input wait to 6 seconds.

**Export notes**

- **Template.** Godot's standard 4.7.2 `web_nothreads_release` template (wasm 39.5 MB). The lean templates in
  `Gamedev\godot-2d-web-template\` are built from 4.5 source and a template must match the engine exactly, so they
  were not used. The game uses only `Button`, `Label`, panel and box containers and custom drawing, so it should
  suit a lean 4.7 template once one exists. That is not tested.
- The preset excludes `tests/*`, `web/*`, `docs/*`, `*.md`, `*.txt` and `LICENSE`. The exported `.pck` was scanned:
  it holds the main scene, the icon and the 24 scripts under `scripts/`, and no test, note or prompt file.
- No threads, so the host needs no cross-origin isolation headers.

## Replacing the placeholder artwork

Put a PNG or SVG with a known name in `assets/bio/` (`platelet`, `platelet_active`, `red_blood_cell`, `pancreas`,
`liver`, `muscle`, `glucose`, `insulin`, `glucagon`); sizes are listed in `assets/bio/README.md`. `scripts/shared/art.gd`
looks the file up and the view draws it in place of the procedural shape. Models never touch artwork. The blood
vessel, wound, fibrin mesh and food are drawn in code only; to restyle them edit `clotting_view.gd` / `glucose_view.gd`.
The lookup was checked on desktop with two temporary PNGs (`platelet`, `pancreas`), which appeared in place of the
placeholders and were then removed. It has not been checked in a web export, or with SVG files.

## How it is put together

```
scenes/Main.tscn                 one node; everything else is built in code
scripts/main.gd                  app shell: top bar, menu, module switching, ?module= setting
scripts/main_menu.gd
scripts/shared/
  timeline_recorder.gd           times, named series, events, state snapshots
  graph_view.gd                  the graph (series, lines, band, events, cursor, scrubbing)
  synth.gd, audio_controller.gd  sound synthesis and playback
  module_base.gd                 fixed time step, shared helpers
  experiment_base.gd             set up -> run -> results -> replay, shared by both experiments
  ui.gd, art.gd, announcer.gd, keyboard_exit.gd
scripts/classroom/  scripts/abstract/  scripts/clotting/  scripts/glucose/
  *_model.gd                     the science: no drawing, no sound
  *_view.gd                      drawing only: reads the model or a recorded snapshot
  *_module.gd                    clock, recording, controls, sound and captions from model events
tests/                           headless tests, screenshot and audio tools, browser checks
web/shell.html                   HTML shell for the export (loading text, live regions)
```

Each model has a comment at the top of its file stating its rules in plain words.

## Implementation decisions

1. **Sound is synthesised into buffers, not streamed.** The GDD suggests `AudioStreamGenerator` "or another lightweight
   built-in approach". Each sound is computed once at start-up into an `AudioStreamWAV` (a sawtooth pair through a
   resonant filter that opens and closes per syllable gives the brass "wah"). Buffers play reliably in a
   single-threaded web export. Each student voice has three variants, played at a random pitch (0.90 to 1.12).
2. **Loudness cap.** At most five chatter voices sound at once, and each extra voice is turned down
   (gain / sqrt(voices)). Further requests are dropped; the student still shows a speech mark.
3. **Replay.** The classroom and abstract demos replay by running the same seed again, which reproduces the curve
   value for value (tested). The two experiments store a state snapshot per model step; replay and scrubbing read
   those snapshots, and the graph cursor uses the same time, so picture and graph cannot drift apart.
4. **Skip.** "Skip" is not defined in the GDD. Classroom: Skip Ahead jumps to the second teacher's arrival, then to
   the end; the skipped part is still simulated step by step, without sound. Abstract: Skip Part moves to the next part.
5. **Third abstract part.** Positive feedback is shown twice, nudged up and then down, because the GDD says it "must
   not be defined as merely making a quantity increase".
6. **Clotting limits.** The plug stops growing because bare wound runs out, each column holds at most three
   platelets, each platelet's signal release fades with age, and release shuts down over 4 s once the wound is
   covered (a stand-in for "local regulatory processes"). The fibrin mesh is a picture only.
7. **Glucose units and time.** Glucose is 0 to 100 "classroom units" with a 40 to 60 target range; hormones are
   0 to 1 activity; one real second is five simulated minutes and an experiment lasts six simulated hours.
   At rest a steady trickle from digestion balances use, so the baseline is flat; Fasting removes it.
8. **Same settings, same seed** in the clotting experiment, so a class can repeat a result exactly.
9. **Volume is two buttons and a number**, not a slider, so every control has the same visible focus outline.
10. **Layout is designed for a 1180 x 500 frame** with the top-right 200 px of the bar left empty for the sims site's
    Full screen button (`Sims_Site_Hosting_Requirements.md`).
11. **Motion: Reduced** stops head and arm movement, red-cell drift, particle drift and caption pop effects. Mouths,
    speech marks, loudness bars, counts and the graph still change. In a browser it starts on if the system asks for
    reduced motion.

## Known limitations and remaining refinements

- **Nobody has listened to it.** The sounds were measured (pitch, level, length) and the browser test confirms the
  game starts them, but the "brass" character and the mix have not been judged by ear. Expect to tune `VOICES` and
  `TEACHER` in `audio_controller.gd`. The teacher's fundamental is 62 Hz; small speakers will carry only its overtones.
- **Checked in headless Chrome only** (Google Chrome 157, software GL). Not yet checked: a visible Chrome window, a
  Chromebook, a phone, Vivaldi, a screen reader, real full-screen Escape behaviour.
- **Small frames.** At 1180 x 360 the whole layout scales to 72 % and stays usable but small; on a phone-shaped frame
  it is too small to use. No text-size option.
- **Screen readers** get only module names, a few event messages and the results text through hidden live regions;
  the pictures and graphs are not described.
- **Biology artwork** is procedural placeholder art. The glucose picture's flow counts are a visual guide, not a scale.
- **Pacing** was set by reasoning and by looking at still frames, not by watching students: the classroom demo runs
  about 42 s, the abstract demo about 70 s, a clotting test 12 to 45 s, a glucose experiment 72 s.
- **Clotting, Reduced signals** differs from Normal only moderately (about 22 against 27 platelets, cover at about
  17 s against 12 s, averaged over 12 seeds); Blocked is the dramatic case.
- Settings (sound, motion) are not saved between visits.

## For the sims site registry

- **Godot version / template:** 4.7.2.stable.official, standard `web_nothreads_release` template, no threads.
- **Title:** Feedback!
- **Description:** Watch and test how positive and negative feedback work, from a noisy classroom to blood clotting and blood glucose.
- **Estimated minutes:** 12 to 20 (not timed with students).
- **Class settings:** `module`, a choice: `classroom`, `abstract`, `clotting`, `glucose`; absent or unknown = main menu.
- **Export:** `..\exports\feedback-sim\`. Not imported, not published.
- **Owner-only (left blank):** level, author, license.

| Accessibility item | State | How it was checked |
| --- | --- | --- |
| Keyboard: all buttons | Works | Headless test (`test_app.gd`: every enabled button is in the Tab ring in every module); headless Chrome: menu, Play, Pause, Skip, Start, Meal, Exercise, Replay, Sound pressed with Tab and Enter |
| Tab / Shift+Tab / Escape leave the game (`sims:leave-game`) | Works | Headless Chrome in a same-origin iframe: focus lands on the host's Full screen button in all three cases |
| Click-to-scrub on the graph | Mouse only; Back / Forward buttons do the same from the keyboard | Headless test |
| No auto-play | Confirmed | Headless Chrome: menu frame pixel-identical after 60 s without input and no sound started; a module stays still and silent until Play |
| Pause | Works in all four modules | Headless test; headless Chrome (classroom frame pixel-identical for 3 s, no new sounds) |
| Colour not the only cue | Shapes, words and line styles accompany colour | By design; viewed in screenshots, not checked with a colour-blindness simulator |
| Contrast | Not measured | Light text on dark panels; dark text on light scenes |
| Screen reader | Not tested | See limitations |
| Phone / Chromebook / physical keyboard | Not yet checked | |
| HTML shell | 0 axe-core violations (WCAG 2.2 AA rule set) | `tests/web/axe_check.js`; axe cannot see inside the canvas |

## Credits

See `CREDITS.md`. No third-party assets.

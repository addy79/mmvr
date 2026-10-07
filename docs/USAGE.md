# MMLabVR usage notes

## Run it
- **Double-click `MMLabVR.godotapp`** in this folder (or run `./MMLabVR.godotapp`).
  It starts in desktop mode, or in VR if an OpenXR runtime is running.
- From the Godot editor: open the project and press F5 (main scene `scenes/main.tscn`).

### Desktop controls
Keys are by position, so on an AZERTY keyboard "W A S D" are the keys printed Z Q S D
(the hint on screen shows your keyboard's letters).
| Input | Action |
|---|---|
| W A S D (Z Q S D on AZERTY), Q / E (A / E), Shift | move, down / up, faster |
| left- or right-drag on the background, or arrow keys | look around |
| scroll wheel / two-finger swipe | move forward / back |
| R | reset the view |
| left-drag the yellow knob | slide the load P along the beam |
| Tab | hide / show the control strip |
| F12 | screenshot to `screenshots/` |

### VR controls (Quest)
| Input | Action |
|---|---|
| grip near the yellow knob | grab the load and slide it along the beam |
| right trigger + laser | use the control panel (on your left) |
| left stick | walk |
| right stick | turn |
The formula board is on your right.

## Install on the Quest
```bash
godot --headless --path . --export-debug "Quest" build/mmlabvr-quest.apk
adb install -r build/mmlabvr-quest.apk
adb shell monkey -p com.example.mmlabvr -c android.intent.category.LAUNCHER 1
```
The app also shows up on the headset under Library → Unknown sources → MMLabVR.

## Tests
```bash
./run_tests.sh                          # GUT unit tests, headless
./run_tests.sh -gselect=test_beam       # only scripts whose name contains "test_beam"
godot --path . -- --selftest            # windowed end-to-end run + screenshots, exit code = failures
godot --path . -- --xr-preview --selftest   # same, with the VR scene seen from the headset start pose
```
Errors you can ignore on a PC: the OpenXR-Loader "failed to load a runtime" lines (no
VR runtime installed), and "Viewport Texture must be set" in XR mode (logged by XR Tools'
own `viewport_2d_in_3d.tscn` when it loads).

## How it fits together
```
ControlPanel ─┐                          ┌─> BeamDataTexture ─> beam_stress / diagram shaders
LoadHandle ───┼─> BeamController ─beam_changed─> BeamView, DiagramView x2, LoadHandle,
(XR grab or   │    (owns SimplySupportedBeam)    FormulaPanel, ControlPanel
 desktop drag)┘
```
- `scripts/physics/`: all the mechanics (RefCounted, unit-tested). Nothing else computes results.
- `scripts/visualization/`: meshes, the data texture, views. Read results only.
- `scripts/interaction/`: controller, load handle, desktop camera/drag, XR rig, input map.
- `scripts/ui/`: panels and `Units` (the only SI -> kN/MPa/mm conversion).
- `scripts/main.gd`: builds the whole scene in code and connects the signals.

Display choices: deflection is drawn at the chosen exaggeration but never more than 0.6 m
(the panel then says "drawn at ×N to fit"); stress colors are full at ±σ_max (auto) or
±σ_Y (relative to yield). Numbers on the board are always the true values.

## In the editor, check once
- Project → Project Settings → Plugins: **Godot XR Tools** and **Gut** enabled.
- Project → Export: preset **Quest** exists (Gradle build on, XR mode OpenXR, Meta plugin on).
- The bottom **GUT** panel can run the same tests as `./run_tests.sh`.
- Close the editor before editing `project.godot` by hand: it rewrites the file on save.

## Addons
| Addon | Version | Notes |
|---|---|---|
| Godot OpenXR Vendors | 5.1.0 | copied from ~/godot-vr-starter |
| Godot XR Tools | 4.5.1 | patched for Godot 4.7, see patches/README.md |
| GUT | 9.7.1 | test framework; excluded from the Quest export. Its editor plugin checks GitHub for updates when the editor opens. |

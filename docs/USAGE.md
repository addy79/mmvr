# MMLabVR usage notes

A VR lab for a Mechanics of Materials course: one bench per chapter, each with a 3D
model you can manipulate, step-by-step lessons with the live numbers substituted into
every equation, and 2D figures (diagrams, σ-ε curve, Mohr's circle...).

## Run it
- **Double-click `MMLabVR.godotapp`** in this folder (or run `./MMLabVR.godotapp`).
  Desktop mode, or VR when an OpenXR runtime is running.
- From the Godot editor: open the project and press F5 (main scene `scenes/main.tscn`).

## Using a chapter
- **Left panel**: pick the chapter, then change its inputs (only the inputs that matter for
  the current lesson step are shown).
- **Right panel**: the lesson. Click the numbered steps (or Previous / Next). Each step
  explains one idea, shows the equation with your current numbers, a figure, and a
  "Try this" experiment.
- **Colored knobs** in the 3D scene can be dragged (yellow = load, cyan = section cut ...).

| Ch. | Bench | Steps |
|---|---|---|
| 1 | Rod, pin and clevis | normal stress, pin shear (single/double), bearing, oblique plane, allowable load |
| 2 | Tension test + bench bar | σ-ε diagram, Hooke's law & resilience, yield to fracture, unloading, PL/AE, Poisson, thermal stress |
| 3 | Shaft in a wall with a lever | deformation, τ = Tρ/J, φ = TL/JG, hollow shafts, power & design |
| 4 | Segment under end couples | plane sections, ε = −y/ρ, flexure formula, 1/ρ = M/EI, section modulus & M_Y |
| 5 | Simply supported beam | free body & reactions, section cut V/M, bending stress, shear stress, stress at a point, deflection, design |
| 6 | Section seen end-on + planks | why horizontal shear, Q, τ = VQ/It, shear flow & nail spacing, I-beam web |
| 7 | Rotatable stress element | plane stress, transformation equations, principal stresses, max shear, Mohr's circle, yield criteria |
| 8 | Sign-post pipe | internal forces, stress from each load, element at a point, principal stresses, von Mises/Tresca |
| 9 | Cantilever or simply supported | curvature, integration & BCs, support conditions, superposition, stiffness design |
| 10 | Column | stability, Euler, end conditions & K, slenderness, secant formula, design |

### Desktop controls
Keys are by position, so on an AZERTY keyboard "W A S D" are the keys printed Z Q S D
(the hint on screen shows your keyboard's letters).
| Input | Action |
|---|---|
| W A S D (Z Q S D on AZERTY), Q / E (A / E), Shift | move, down / up, faster |
| left- or right-drag on the background, or arrow keys | look around |
| scroll wheel / two-finger swipe | move forward / back |
| R | reset the view |
| left-drag a colored knob | move a load, cut or level |
| Tab | hide / show the panels |
| F12 | screenshot to `screenshots/` |

### VR controls (Quest)
| Input | Action |
|---|---|
| grip near a colored knob | grab it and slide it |
| right trigger + laser | use the panels (controls on your left, lesson on your right) |
| right stick up/down | scroll the lesson |
| left stick | walk |
| right stick left/right | turn |

## Install on the Quest
```bash
godot --headless --path . --export-debug "Quest" build/mmlabvr-quest.apk
adb install -r build/mmlabvr-quest.apk
adb shell monkey -p com.example.mmlabvr -c android.intent.category.LAUNCHER 1
```
The app also shows up on the headset under Library → Unknown sources → MMLabVR.

## Tests
```bash
./run_tests.sh                          # GUT unit tests of all physics, headless
./run_tests.sh -gselect=test_euler      # only scripts whose name contains "test_euler"
godot --path . -- --selftest            # windowed: every chapter and step + numeric checks + screenshots
godot --path . -- --selftest --3d-shots # also saves a panel-free 3D view of every step
godot --path . -- --xr-preview --selftest   # the VR layout, seen from the headset start pose
```
The self-test's exit code is the number of failed checks. Errors you can ignore on a PC:
the OpenXR-Loader "failed to load a runtime" lines (no VR runtime installed), and
"Viewport Texture must be set" in XR mode (logged by XR Tools' own `viewport_2d_in_3d.tscn`).

## How it fits together
```
ControlPanel ──set_control──┐
station knobs (AxisKnob) ───┴─> Station (one per chapter) ──changed──> ControlPanel.sync,
                                  owns its physics model + 3D scene      LessonPanel.refresh
```
- `scripts/physics/`: all the mechanics (RefCounted, unit-tested against hand calculations).
  Every number shown anywhere comes from here.
- `scripts/stations/`: one script per chapter (scene building, lesson text, figures) plus
  `Station` and `ControlSpec`.
- `scripts/visualization/`: meshes, data texture, arrows, stress element, beam rig.
- `scripts/interaction/`: knobs, desktop camera and drag, XR rig, input map.
- `scripts/ui/`: panels, plots, Mohr's circle, BBCode lesson helpers, `Units` (the only
  SI → kN/MPa/mm conversion).
- `scripts/main.gd`: builds the lab in code and switches stations.

Display choices: deformations are drawn exaggerated where they are invisible at true scale
(the factor is always shown); small parts are drawn larger than life where noted. Numbers
on the panels are always the true values.

## Addons
| Addon | Version | Notes |
|---|---|---|
| Godot OpenXR Vendors | 5.1.0 | copied from ~/godot-vr-starter |
| Godot XR Tools | 4.5.1 | patched for Godot 4.7, see patches/README.md |
| GUT | 9.7.1 | test framework; excluded from the Quest export. Its editor plugin checks GitHub for updates when the editor opens. |

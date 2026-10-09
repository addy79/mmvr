# MMLabVR: Mechanics of Materials in VR

A virtual-reality lab for a university **Mechanics of Materials** course. It has one interactive
3D bench for each of the 10 course chapters (stress, axial loading, torsion, bending, beams,
shear, stress transformation, principal stresses, deflection, columns). It also has one bench
for each of the course's lab experiments (Labs 1–11), with a saved **done / to do** mark per lab.

It runs on a PC (keyboard and mouse) and on a **Meta Quest** headset.

---

## At a glance

| | |
|---|---|
| **Language** | GDScript (Godot's Python-like scripting language), plus a few GLSL shaders (`shaders/`) |
| **Engine** | Godot 4.7.2, Forward Mobile renderer, OpenXR for VR |
| **Platforms** | Linux desktop (also works without a headset), Meta Quest (Android APK) |
| **Addons** | Godot XR Tools 4.5.1 (patched for Godot 4.7), Godot OpenXR Vendors 5.1.0, GUT 9.7.1 (tests) |
| **Units** | SI internally (N, m, Pa). `scripts/ui/units.gd` is the only place that converts to kN, MPa or mm for display |
| **Tests** | 93 unit tests of the physics (GUT) + a windowed self-test with 169 checks |

---

## Where do the numbers come from?

**Short answer:** the numbers come from **analytical formulas from the textbook**, plus one
real **finite element solver** for Lab 3. They do **not** come from a game physics engine,
and nothing is approximated by animation.

- **Chapters 1–10:** every value shown (stress, strain, deflection, angle of twist,
  critical load...) is computed with the closed-form equations of Beer & Johnston,
  *Mechanics of Materials*. Examples are σ = P/A, τ = Tc/J, σ = Mc/I, τ = VQ/It, Mohr's
  circle, beam deflection by integration and superposition, and Euler buckling.
- **All formulas live in `scripts/physics/`.** These are pure calculation classes with no
  graphics, and each formula is commented with its equation. The 3D scenes and lesson panels
  only *display* the results; they never compute physics themselves.
- **Every formula is unit-tested** against a hand calculation, to within 1 % (`tests/`).
- **Lab 3** (geometry and stress) runs a **real 2D finite element analysis**: plane stress,
  4-node quadrilateral (Q4) elements on a structured mesh, solved with a banded Cholesky
  factorization (`scripts/physics/plane_stress_fem.gd`). It shows von Mises stress and strain
  contours and a mesh-convergence study, like the ANSYS model in the handout.
- **Lab readings are simulated.** The tables in each lab bench are filled from the same
  physics models:
  - **Ideal** gives the exact theoretical value.
  - **Realistic scatter** gives the theoretical value plus a small *repeatable* random error
    (seeded, so it is the same every run), rounded to the instrument's resolution
    (`scripts/labs/lab_station.gd`).

  These readings are for learning and for checking your own results. **Use your own
  measured data in your lab reports.**
- **Device dimensions** that the handouts don't give (spring stiffness of the tensile unit,
  torsion lever length, some bar sizes) are **adjustable sliders with placeholder defaults**.
  Set them to match your machine.
- **Default materials:** A36 steel (E = 200 GPa, σ_Y = 250 MPa), 6061-T6 aluminum
  (70 GPa, 240 MPa), Douglas fir (13 GPa) and gray cast iron. The beam conventions follow
  Beer & Johnston: deflection v is positive **downward**, and M is positive for sagging.
- **What you see vs. the true values:** deformations too small to see are drawn
  exaggerated (the factor is always shown), and small parts are drawn larger than life. The
  numbers on the panels are always the true, unscaled values.

---

## How to use it

### Start it
- **On the PC:** double-click **`MMLabVR.godotapp`** in this folder (or run `./MMLabVR.godotapp`).
- **From the Godot editor:** open the project and press **F5**.
- **On the Quest:** see [Install on the Quest](#install-on-the-quest).

### Learn a chapter
1. In the **left panel**, pick a chapter (1–10). The inputs for that chapter appear below
   (loads, lengths, section, material...). Only the inputs that matter for the current step
   are shown.
2. The **right panel** is the lesson. Go through the numbered steps (or Previous / Next).
   Each step explains one idea and shows its equation **with your current numbers
   substituted**, a 2D figure (shear/moment diagram, σ-ε curve, Mohr's circle...) and a
   "Try this" experiment.
3. Change an input, or **drag a colored knob** in the 3D scene (yellow = load,
   cyan = section cut). The model, the numbers and the figures all update live.

### Prepare or review a lab
1. Under **Lab experiments** in the left panel, open a lab. Each one follows its handout:
   objective and theory, apparatus, the handout's data tables (simulated), plots with line
   fits, and guidance for the report questions.
2. Set the sliders to match your specimen and machine, and choose **Ideal** or **Realistic
   scatter** readings.
3. Tick **"I have done this lab"** to mark it done. The marks are saved on the device, and
   the list shows a done / to-do count. Lab 6 has no handout yet, so it is greyed out.

### Controls

**Desktop.** Keys work by position, so on an AZERTY keyboard W A S D are the keys printed
Z Q S D. The on-screen hint shows your keyboard's own letters.

| Input | Action |
|---|---|
| W A S D, Q / E, Shift | move, down / up, faster |
| drag the background, or arrow keys | look around |
| scroll wheel / two-finger swipe | move forward / back |
| R | reset the view |
| drag a colored knob | move a load, cut or level |
| Tab | hide / show the panels |
| F12 | screenshot to `screenshots/` |

**VR (Quest).**

| Input | Action |
|---|---|
| grip near a colored knob | grab and slide it |
| right trigger + laser | use the panels (controls on your left, lesson on your right) |
| right stick up / down | scroll the lesson |
| left stick | walk |
| right stick left / right | turn |

In VR, the chapter and lab lists fold away after you pick one (**▶ Show chapters and labs**
brings them back).

---

## What each lab bench does

| Lab | Bench | What it computes |
|---|---|---|
| 1 | Tensile testing unit (MTTU): three springs, dog-bone specimen | F = k·ΔL from the dial gauge, σ = F/A, readings to fracture (pure Al, Al 5754-H111) |
| 2 | MTTU, steel and aluminum | δ = L_up − ΔL, ε = δ/L₀, σ-ε chart, line fit → E, why the MTTU's E is unreliable |
| 3 | FEM model: cuboid, cylinder, dog-bone | real 2D FEM solve, von Mises contours, shape comparison, mesh convergence |
| 4 | Signpost with offset sign (ANSYS check) | base forces, bending from the wind and the eccentric sign weight, torsion from the wind on the sign, von Mises, deflections, factor of safety |
| 5 | Torsion machine | φ = TL/(JG), load-angle tables and fits, G from the slope, effect of length |
| 7 | Bar on two supports | δ = Fl³/(48EI) vs. measured, ranking by I, brass E from a slope |
| 8 | 500×20×4 bar in three set-ups | cantilever / simply supported / overhang deflections and ranking |
| 9 | Shear force and bending moment unit (Edibon MMF) | balancing masses: Q = W₁ = W, M = W₂·a = W·x at the cut; SFD/BMD; experiment vs. theory |
| 10 | W200×52 vs. S250×52 beams | flange stress, web shear, von Mises, which section is stronger |
| 11 | Usual, narrow and hollow cantilevers | deflection including shear deformation, σ, τ = VQ/It, maximum shear stress (Tresca) |

The chapter-by-chapter step list is in [`docs/USAGE.md`](docs/USAGE.md).

---

## How it was built (process)

1. **Physics first.** Each mechanics topic was written as a calculation class in
   `scripts/physics/`, with a GUT test comparing it to a hand calculation (within 1 %).
2. **Stations.** Each chapter was then built as a "station" (`scripts/stations/`): the 3D
   model, the lesson text with live equations, figures and the input controls. The labs
   (`scripts/labs/`) were added on a shared `LabStation` base, from the course handouts.
3. **Checked against the handouts.** The lab benches were compared with the figures inside
   the handouts. Lab 4 (offset sign) and Lab 9 (free-arm device) were rebuilt to match them.
4. **End-to-end self-test.** A windowed test opens every chapter, lab and step, checks the
   key numbers on screen against hand values, and saves screenshots for visual review.
5. **Small git commits** after each verified step.

### Code layout

```
scripts/physics/        all the mechanics: pure calculation classes, unit-tested
scripts/stations/       one script per chapter: 3D scene, lesson text, figures, controls
scripts/labs/           one script per lab, on the LabStation base (simulated readings)
scripts/visualization/  meshes, arrows, stress element, beam rig, tensile machine...
scripts/interaction/    knobs, desktop camera, XR rig, input map
scripts/ui/             panels, plots, Mohr's circle, Units (the only unit conversion)
scripts/main.gd         builds the lab in code and switches stations
shaders/                GPU bending / twisting deformation and stress coloring (fed by the physics results)
tests/                  GUT unit tests + scene_selftest.gd
labs handouts/          your course handouts (.docx, not tracked in git)
```

---

## Tests

```bash
./run_tests.sh                              # 93 physics unit tests, headless (~1 s)
godot --path . -- --selftest                # every chapter, lab and step + numeric checks + screenshots
godot --path . -- --selftest --3d-shots     # also panel-free 3D screenshots (~10 min)
godot --path . -- --selftest --lab 9        # one lab only (or --chapter N)
godot --path . -- --xr-preview --selftest   # the VR layout, seen from the headset
```

The self-test's exit code is the number of failed checks, and its screenshots go to
`screenshots/`. On a PC you can ignore the "OpenXR-Loader ... failed to load a runtime"
lines (no VR runtime installed).

---

## Install on the Quest

You need the Godot Android export setup (JDK 17, Android SDK) and the headset connected by USB
with developer mode on.

```bash
godot --headless --path . --export-debug "Quest" build/mmlabvr-quest.apk
adb install -r build/mmlabvr-quest.apk
adb shell monkey -p com.example.mmlabvr -c android.intent.category.LAUNCHER 1
```

On the headset, the app is under **Library → Unknown sources → MMLabVR**.

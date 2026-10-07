# MMLabVR usage notes

## Run the unit tests (headless)
```bash
./run_tests.sh                          # all tests
./run_tests.sh -gselect=test_beam       # only scripts whose name contains "test_beam"
```
The OpenXR-Loader "failed to load a runtime" errors are expected on a PC
without a VR runtime and can be ignored.

## Addons
| Addon | Version | Notes |
|---|---|---|
| Godot OpenXR Vendors | 5.1.0 | copied from ~/godot-vr-starter |
| Godot XR Tools | 4.5.1 | patched for Godot 4.7, see patches/README.md |
| GUT | 9.7.1 | test framework; excluded from the Quest export |

# Anatomy Layer Pipeline

The Create/Edit Exercise page uses 3D-derived anatomy still artwork as the
visual base, then stacks transparent per-muscle diff layers:

- Runtime widget: `gymmer_flutter/lib/widgets/exercise_anatomy_panel.dart`
- Runtime assets: `gymmer_flutter/assets/muscle_layers/`
  - `base_front.png` / `base_back.png`
  - `<Muscle>_front.png` / `<Muscle>_back.png` primary diff layers
  - `<Muscle>_front_secondary.png` / `<Muscle>_back_secondary.png` secondary diff layers
  - `<Muscle>_front_mask.png` / `<Muscle>_back_mask.png` compatibility masks
- Source stills: `backup/assets/muscle_stills/<Muscle>_<front|back>.png`
  for exact 2D silhouettes, edge anti-aliasing, and still shading
- Source model: `gymmer_flutter/assets/models/full-body.glb` for original
  muscle material textures used by primary layers

There are no pre-rendered primary+secondary combo stills in the app bundle.
Any custom exercise combo works by stacking over the light-gray base still:
secondary diff layers first, then primary diff layers on top. Unselected
muscles stay light gray from the base still.

## How to regenerate layers

```powershell
cd flutter_only\gymmer_flutter
npm install
npm run plate     # step 1: render the aligned real-colour plate (delts + abs)
npm run layers    # step 2: build the runtime diff layers
```

`tools/render_color_plate.js` (step 1) renders `full-body.glb` at the exact
still camera with every muscle in its real texture and the textureless delt
part overlays hidden, writing `backup/assets/muscle_plate/plate_<view>.png`.
Because it reuses the same GLB and camera as the masks, the plate is
pixel-aligned to them (no reprojection). See the tool header for the two
offline gotchas it handles (Draco decompress + Chromium swiftshader flag).

`tools/render_muscle_layers.js` (step 2) reads the archived primary-only anatomy
stills to keep the exact 2D silhouettes and edge anti-aliasing, builds a
light-gray base still for each view, then writes primary and secondary
transparent diff layers for each muscle:

- Most muscles pull their original material texture from `full-body.glb`
  (`HL_<Muscle>`); muscles whose GLB material has no image texture fall back to
  the rendered still shading.
- **Delts and abs** (`PLATE_MUSCLES`) instead sample the aligned colour plate
  inside each part mask, so each shows its real fibre texture in its true
  location. The `Deltoid muscle.r` full-cap texture is cut by the Front/Rear/Side
  part masks; **Side Delt only claims the pixels Front and Rear did not**
  (`mask_side − (mask_front ∪ mask_rear)`), so the middle head never steals
  anterior/posterior pixels. Abs samples the whole abdominal-wall mask (rectus
  centre + oblique flanks) straight from the plate — no more oblique-texture /
  rectus-sheath approximation. Note the rectus sheath reads pale in the source
  texture, so the abs highlight is faithful but soft through the centre.

## Model chain

- `assets/models/full-body.glb` (~6 MB, kept on disk, NOT bundled into the
  app) — muscle-focused model with per-group `HL_<Group>` highlight materials,
  used by offline model/still tooling.
- Built by `tools/build_full_body.js` + `tools/highlight_groups.json` from 4
  source GLBs which are now archived in `flutter_only/backup/models/`
  (originally from anatomytool.org / Sketchfab). Restore them from backup (or
  re-download) only if full-body.glb itself must be rebuilt.
- The model is a right hemibody (all meshes `.r`); stills render front
  (az 0) and back (az 180) — az 90 is the hollow mid-sagittal cut.

## Licensing — ship-blocking for commercial builds

- Upper/lower limb + skeleton sources: **CC BY-SA 4.0** (anatomytool.org,
  University of Groningen). Attribution required:
  "Contains or derives from Open3DModel assets by AnatomyTOOL and
  participating anatomy departments, licensed under CC BY-SA.
  See https://anatomytool.org/open3dmodel."
- Thorax/abdomen (abs) source: **CC BY-NC-SA 4.0** (NonCommercial) —
  https://sketchfab.com/3d-models/thorax-and-abdomen-a-few-important-muscles-a6831716a15540d1889efb57305572f8
  Accepted 2026-07-06 on the basis that GYMMER is non-commercial. If GYMMER
  ever becomes commercial (paid, ads, IAP), the abs-derived stills must be
  re-licensed or re-rendered from a CC BY-SA alternative
  (candidate: BodyParts3D/Anatomography, CC BY-SA).
- Generated base images and primary/secondary diff layers are derivatives of
  these sources and inherit the terms.
- Never embed AnatomyTOOL's viewer code (GPLv3) — model files only.

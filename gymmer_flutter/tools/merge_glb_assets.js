// Merges the 4 AnatomyTOOL source GLB files into a single GLB with ONE scene
// containing all root nodes, so <model-viewer> renders all of them together.
//
// The previous approach (`gltf-transform merge`) produced a file with 4 separate
// scenes — <model-viewer> only renders the default scene, so only one model
// showed up. This script instead:
//   1. Reads each source doc
//   2. Copies every root node from its default scene into a new merged doc
//   3. Writes ONE scene that contains all copied roots
//
// The source models already share a common anatomical origin (see bbox y-ranges
// reported by `gltf-transform inspect`), so no per-model transform is needed.
//
// Run from `gymmer_flutter/`:
//   node tools/merge_glb_assets.js

const path = require('node:path');
const { NodeIO } = require('@gltf-transform/core');
const { KHRONOS_EXTENSIONS } = require('@gltf-transform/extensions');
const { mergeDocuments, unpartition } = require('@gltf-transform/functions');
const draco3d = require('draco3dgltf');

const MODELS_DIR = path.resolve(__dirname, '..', 'assets', 'models');
const SOURCES = [
  'muscles-thorax-abdomen.glb',
  'upper-limb.glb',
  'lower-limb.glb',
  'overview-skeleton.glb',
];
const OUTPUT = 'full-anatomy.glb';

async function main() {
  const io = new NodeIO()
    .registerExtensions(KHRONOS_EXTENSIONS)
    .registerDependencies({
      'draco3d.decoder': await draco3d.createDecoderModule(),
      'draco3d.encoder': await draco3d.createEncoderModule(),
    });

  const target = await io.read(path.join(MODELS_DIR, SOURCES[0]));
  const targetRoot = target.getRoot();
  const targetScene = targetRoot.listScenes()[0];
  targetScene.setName('Full Anatomy');

  for (let i = 1; i < SOURCES.length; i++) {
    const src = await io.read(path.join(MODELS_DIR, SOURCES[i]));
    mergeDocuments(target, src);

    // After merge, `src`'s scene(s) exist in `target` but are not attached
    // to `targetScene`. Reparent their root nodes into `targetScene`, then
    // drop the extra scenes.
    const scenes = targetRoot.listScenes();
    for (const scene of scenes) {
      if (scene === targetScene) continue;
      for (const node of scene.listChildren()) {
        scene.removeChild(node);
        targetScene.addChild(node);
      }
      scene.dispose();
    }
  }

  targetRoot.setDefaultScene(targetScene);

  // GLB requires a single buffer; each mergeDocuments call preserves the source buffer.
  await target.transform(unpartition());

  await io.write(path.join(MODELS_DIR, OUTPUT), target);
  const finalScenes = targetRoot.listScenes();
  const finalRootCount = targetScene.listChildren().length;
  console.log(
    `Wrote ${OUTPUT} — scenes=${finalScenes.length}, roots=${finalRootCount}`,
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

/*
 * Builds a muscle-focused full-body model from the 4 AnatomyTOOL/skeleton sources.
 *
 * Filtering rules (per user spec):
 *   - upper-limb.glb          -> keep only "* - muscles" folders
 *   - lower-limb.glb          -> keep only the "Muscles" folder
 *   - overview-skeleton.glb   -> keep everything
 *   - muscles-thorax-abdomen  -> keep only the abdominal-wall (abs) muscle meshes
 *
 * Each source keeps its original local origin/scale (the sources already share one
 * anatomical origin, same assumption as tools/merge_glb_assets.js). Output is one
 * scene "Full Body" with every kept folder reparented under it.
 *
 * Run:  node tools/build_full_body.js
 * Deps: @gltf-transform/core, @gltf-transform/functions  (installed under tools/ or via npm)
 */
const path = require('path');
const { NodeIO, Document } = require('@gltf-transform/core');
const { ALL_EXTENSIONS } = require('@gltf-transform/extensions');
const { prune, mergeDocuments } = require('@gltf-transform/functions');
const draco3d = require('draco3dgltf');

async function makeIO() {
  return new NodeIO()
    .registerExtensions(ALL_EXTENSIONS)
    .registerDependencies({
      'draco3d.decoder': await draco3d.createDecoderModule(),
      'draco3d.encoder': await draco3d.createEncoderModule(),
    });
}

const MODELS = path.resolve(__dirname, '../gymmer_flutter/assets/models');
const OUTPUT = path.join(MODELS, 'full-body.glb');

// Highlight template + mesh removals (source of truth: tools/highlight_groups.json).
const TEMPLATE = require('./highlight_groups.json');

// Abs = anterior/lateral abdominal wall plus the anterior rectus sheath overlay.
// Excluded on purpose: Iliacus, Psoas major/minor (hip flexors), Linea alba, and
// posterior rectus sheath.
const ABS_MESHES = new Set([
  'External abdominal oblique muscle.r',
  'Internal abdominal oblique muscle.r',
  'Transverse abdominal muscle.r',
  'Pyramidalis muscle.r',
  'Rectus abdominal muscle.r',
  'Rectus sheath (Anterior leaf overlay).r',
]);

// Decide whether a top-level folder node from a source should be kept.
function keepRoot(fileKey, name) {
  const n = name.toLowerCase();
  switch (fileKey) {
    case 'upper':
    case 'lower':
      return n.includes('muscle'); // "* - muscles" (upper) / "Muscles" (lower)
    case 'skeleton':
      return true;
    case 'abs':
      return name === 'Muscles of abdomen'; // trimmed to abs meshes below
    default:
      return false;
  }
}

const SOURCES = [
  { key: 'abs', file: 'muscles-thorax-abdomen.glb' },
  { key: 'upper', file: 'upper-limb.glb' },
  { key: 'lower', file: 'lower-limb.glb' },
  { key: 'skeleton', file: 'overview-skeleton.glb' },
];

async function main() {
  const io = await makeIO();

  const outDoc = new Document();
  const outScene = outDoc.createScene('Full Body');
  const outRoot = outDoc.getRoot();
  outRoot.setDefaultScene(outScene);

  const summary = [];

  for (const { key, file } of SOURCES) {
    const doc = await io.read(path.join(MODELS, file));
    const scene = doc.getRoot().listScenes()[0];

    // Drop unwanted top-level folders.
    for (const node of scene.listChildren()) {
      const name = node.getName() || '';
      if (!keepRoot(key, name)) {
        node.dispose();
        continue;
      }
      // For the abs folder, trim its children down to the abs muscle meshes.
      if (key === 'abs' && name === 'Muscles of abdomen') {
        for (const child of node.listChildren()) {
          if (!ABS_MESHES.has(child.getName() || '')) child.dispose();
        }
      }
    }

    // Remove now-orphaned meshes/materials/accessors so the merge stays lean.
    await doc.transform(prune());

    const keptFolders = scene.listChildren().map((c) => c.getName());
    const meshCount = doc.getRoot().listMeshes().length;
    summary.push({ file, folders: keptFolders.length, meshes: meshCount, names: keptFolders });

    // Merge this trimmed source into the output document, then reparent its
    // surviving root folders under the single "Full Body" scene.
    mergeDocuments(outDoc, doc);
    // After merge, the source's scene(s) exist in outDoc; move their roots over.
    for (const s of outDoc.getRoot().listScenes()) {
      if (s === outScene) continue;
      for (const child of s.listChildren()) outScene.addChild(child);
      s.dispose();
    }
  }

  // --- Remove redundant/overlapping meshes (e.g. pec/trapezius sub-parts). ---
  const meshNodes = () => outDoc.getRoot().listNodes().filter((n) => n.getMesh());
  const removeSet = new Set(TEMPLATE.removeFromPectoralGirdleMuscles || []);
  const removed = [];
  for (const node of meshNodes()) {
    if (removeSet.has(node.getName())) { removed.push(node.getName()); node.dispose(); }
  }

  // --- Split materials per highlight group so each group is recolorable at runtime. ---
  // Each group's meshes are reassigned to a fresh material named "HL_<Group>",
  // cloned from the group's first mesh so the default appearance is unchanged.
  const byName = new Map();
  for (const node of meshNodes()) byName.set(node.getName(), node);
  const resolve = (name) => (byName.has(name) ? name : byName.has(name + '.r') ? name + '.r' : null);

  const highlightReport = [];
  for (const [group, list] of Object.entries(TEMPLATE.groups || {})) {
    const nodes = [];
    const missing = [];
    for (const raw of list) {
      const key = resolve(raw);
      if (key) nodes.push(byName.get(key)); else missing.push(raw);
    }
    if (nodes.length === 0) { highlightReport.push({ group, resolved: 0, missing }); continue; }
    const matName = 'HL_' + group.replace(/\s+/g, '_');
    const base = nodes[0].getMesh().listPrimitives()[0].getMaterial();
    const hlMat = base.clone().setName(matName);
    for (const node of nodes) {
      for (const prim of node.getMesh().listPrimitives()) prim.setMaterial(hlMat);
    }
    highlightReport.push({ group, matName, resolved: nodes.length, missing });
  }

  // Final cleanup pass.
  await outDoc.transform(prune());

  // Each merged source brought its own buffer; a GLB needs exactly one.
  const buffers = outDoc.getRoot().listBuffers();
  const mainBuffer = buffers[0];
  for (const accessor of outDoc.getRoot().listAccessors()) accessor.setBuffer(mainBuffer);
  buffers.slice(1).forEach((b) => b.dispose());

  await io.write(OUTPUT, outDoc);

  console.log('Wrote', path.relative(process.cwd(), OUTPUT));
  console.log('Total root folders:', outScene.listChildren().length);
  console.log('Total meshes:', outDoc.getRoot().listMeshes().length);
  console.log('');
  for (const s of summary) {
    console.log(`  ${s.file}: kept ${s.folders} folder(s)`);
    for (const nm of s.names) console.log(`      - ${nm}`);
  }

  console.log('');
  console.log('Removed meshes:', removed.length ? removed.join(', ') : '(none)');
  console.log('');
  console.log('Highlight groups (material -> #meshes):');
  for (const r of highlightReport) {
    const miss = r.missing.length ? `  MISSING: ${r.missing.join(', ')}` : '';
    console.log(`  ${r.matName || r.group}: ${r.resolved} mesh(es)${miss}`);
  }
}

main().catch((e) => { console.error(e); process.exit(1); });

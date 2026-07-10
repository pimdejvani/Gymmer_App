/*
 * Renders the muscle "colour plate" used by render_muscle_layers.js for the
 * delts and abs (see docs/ANATOMY_STILLS.md + plans/delts-abs-rework-spec.md).
 *
 * It draws full-body.glb at the EXACT still camera (az 0 front / az 180 back,
 * 700x1000, orbit 105%) with every muscle in its REAL baseColorTexture (white
 * factor, texture kept) instead of the red highlight, and hides textureless
 * muscle overlay meshes (the HL_Front/Side/Rear_Delt part overlays) so the
 * textured "Deltoid muscle.r" underneath shows through.
 *
 * Same GLB + camera as the part masks -> the plate is pixel-aligned with them,
 * so render_muscle_layers.js can sample it inside each mask with no reprojection.
 *
 * Two gotchas are handled here so it runs offline on modern Chromium:
 *   1. full-body.glb is Draco-compressed and model-viewer can't fetch the Draco
 *      decoder offline -> we decompress to a temp GLB first (geometry/camera
 *      unchanged, so alignment is preserved).
 *   2. Chromium 131 dropped the automatic software-WebGL fallback -> launch with
 *      headless:'new' + --enable-unsafe-swiftshader or the model never loads.
 *
 * Output: <out>/plate_front.png, plate_back.png (default: backup/assets/muscle_plate)
 * Run:    cd gymmer_flutter && npm run plate
 */
const http = require('http');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { createRequire } = require('module');
const appRequire = createRequire(path.resolve(__dirname, '../gymmer_flutter/package.json'));
const puppeteer = appRequire('puppeteer');

function arg(name, def) {
  const i = process.argv.indexOf('--' + name);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : def;
}
const SRC_GLB = path.resolve(__dirname, '../gymmer_flutter/assets/models/full-body.glb');
const MV_FILE = path.resolve(__dirname, 'vendor/model-viewer.min.js');
const OUT = path.resolve(process.cwd(), arg('out', path.resolve(__dirname, '../backup/assets/muscle_plate')));
const GLB_URL = 'assets/full-body.glb';
const MV_URL = 'vendor/model-viewer.min.js';
const SIZE = { w: 700, h: 1000 };

// Decompress the Draco mesh compression into a temp GLB so model-viewer can load
// it offline. Geometry, transforms and camera framing are untouched.
async function decompressToTemp() {
  const { NodeIO } = appRequire('@gltf-transform/core');
  const { ALL_EXTENSIONS } = appRequire('@gltf-transform/extensions');
  const draco3d = appRequire('draco3dgltf');
  const io = new NodeIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({
    'draco3d.decoder': await draco3d.createDecoderModule(),
    'draco3d.encoder': await draco3d.createEncoderModule(),
  });
  const doc = await io.read(SRC_GLB);
  for (const ext of doc.getRoot().listExtensionsUsed()) {
    if (ext.extensionName === 'KHR_draco_mesh_compression') ext.dispose();
  }
  const tmp = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'gymmer-plate-')), 'full-body-raw.glb');
  await io.write(tmp, doc);
  return tmp;
}

// Materials used by meshes inside muscle folders (same detection as the stills tool):
// these are the textureless overlays we hide so the muscle beneath shows.
function muscleMaterialNames(glbFile) {
  const buf = fs.readFileSync(glbFile);
  const g = JSON.parse(buf.slice(20, 20 + buf.readUInt32LE(12)).toString('utf8'));
  const nodes = g.nodes || [], meshes = g.meshes || [], mats = g.materials || [];
  const FOLDERS = new Set(['Muscles of abdomen', 'Arm - muscles', 'Forearm - muscles',
    'Hand and wrist - muscles', 'Pectoral girdle - muscles', 'Muscles']);
  const parent = {};
  nodes.forEach((n) => (n.children || []).forEach((c) => (parent[c] = n.name)));
  const out = {};
  nodes.forEach((n, i) => {
    if (n.mesh === undefined || !FOLDERS.has(parent[i])) return;
    for (const prim of meshes[n.mesh].primitives || []) {
      const nm = (mats[prim.material] || {}).name;
      if (nm) out[nm] = true;
    }
  });
  return out;
}

function renderHtml() {
  return `<!doctype html><html><head><meta charset="utf-8"/>
<style>html,body{margin:0;background:transparent}model-viewer{width:${SIZE.w}px;height:${SIZE.h}px;--poster-color:transparent}</style>
<script type="module" src="${MV_URL}"></script></head>
<body>
<model-viewer id="v" src="${GLB_URL}" exposure="1.1" shadow-intensity="0"
  interaction-prompt="none" disable-zoom camera-orbit="0deg 90deg 105%"></model-viewer>
<script>
  const mv = document.getElementById('v');
  const WHITE = [1,1,1,1];
  window.__grayMats = window.__grayMats || {};
  const hasTexture = (m) => {
    const bt = m.pbrMetallicRoughness.baseColorTexture;
    return !!(bt && bt.texture);
  };
  window.__setup = (az) => new Promise((resolve) => {
    const paint = () => {
      const mats = (mv.model && mv.model.materials) || [];
      let shown = 0, hidden = 0;
      for (const m of mats) {
        const nm = m.name || '';
        if (hasTexture(m)) {
          m.pbrMetallicRoughness.setBaseColorFactor(WHITE);  // show real texture
          shown++;
        } else if (window.__grayMats[nm]) {
          try { m.setAlphaMode('BLEND'); } catch (e) {}       // hide textureless overlay
          m.pbrMetallicRoughness.setBaseColorFactor([1,1,1,0]);
          hidden++;
        }
      }
      mv.cameraOrbit = az + 'deg 90deg 105%';
      mv.jumpCameraToGoal();
      requestAnimationFrame(() => requestAnimationFrame(() => resolve({ shown, hidden })));
    };
    if (mv.loaded) paint(); else mv.addEventListener('load', paint, { once: true });
  });
</script></body></html>`;
}

const TYPES = { '.js': 'text/javascript', '.glb': 'model/gltf-binary', '.wasm': 'application/wasm' };
function startServer(glbFile) {
  const FILES = { ['/' + GLB_URL]: glbFile, ['/' + MV_URL]: MV_FILE };
  return new Promise((resolve) => {
    const srv = http.createServer((req, res) => {
      const urlPath = decodeURIComponent(req.url.split('?')[0]);
      if (urlPath === '/render') { res.writeHead(200, { 'Content-Type': 'text/html' }); return res.end(renderHtml()); }
      const fp = FILES[urlPath];
      if (!fp) { res.writeHead(404); return res.end('404'); }
      res.writeHead(200, { 'Content-Type': TYPES[path.extname(fp).toLowerCase()] || 'application/octet-stream' });
      fs.createReadStream(fp).pipe(res);
    });
    srv.listen(0, () => resolve(srv));
  });
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  console.log('Decompressing Draco...');
  const glbFile = await decompressToTemp();

  const srv = await startServer(glbFile);
  const port = srv.address().port;
  const browser = await puppeteer.launch({ headless: 'new', args: ['--no-sandbox', '--enable-unsafe-swiftshader'] });
  const page = await browser.newPage();
  page.on('pageerror', (e) => console.log('  [pageerror]', e.message));
  await page.setViewport({ width: SIZE.w, height: SIZE.h, deviceScaleFactor: 1 });
  await page.goto(`http://localhost:${port}/render`, { waitUntil: 'networkidle0' });
  await page.evaluate((gray) => { window.__grayMats = gray; }, muscleMaterialNames(glbFile));
  await page.waitForFunction(() => document.getElementById('v') && document.getElementById('v').loaded, { timeout: 60000 });

  for (const [az, view] of [['0', 'front'], ['180', 'back']]) {
    const info = await page.evaluate((a) => window.__setup(a), az);
    await new Promise((r) => setTimeout(r, 300));
    await page.screenshot({ path: path.join(OUT, `plate_${view}.png`), omitBackground: true });
    console.log(`  plate_${view}.png  (textured: ${info.shown}, hidden overlays: ${info.hidden})`);
  }
  await browser.close();
  srv.close();
  console.log(`\nWrote plates to ${OUT}`);
})().catch((e) => { console.error(e); process.exit(1); });

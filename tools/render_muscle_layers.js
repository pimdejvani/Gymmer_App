/*
 * Builds runtime anatomy layers as transparent diff-style overlays.
 *
 * Sources:
 *   - backup/assets/muscle_stills/<Muscle>_<front|back>.png for exact 2D
 *     anatomy still silhouettes and shading
 *   - gymmer_flutter/assets/models/full-body.glb for original muscle textures
 *     (most muscles) and
 *   - backup/assets/muscle_plate/plate_<front|back>.png, the aligned real-colour
 *     render used for delts + abs (see tools/render_color_plate.js; run first).
 * Output: gymmer_flutter/assets/muscle_layers/
 *   - base_front.png / base_back.png
 *   - <Muscle>_front.png / <Muscle>_back.png primary diff layers
 *   - <Muscle>_front_secondary.png / <Muscle>_back_secondary.png secondary diff layers
 *   - <Muscle>_front_mask.png / <Muscle>_back_mask.png compatibility masks
 *
 * Flutter stacks base -> secondary diff -> primary diff. Unselected muscles stay
 * light gray in the base image.
 */
const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const appRequire = createRequire(path.resolve(__dirname, '../gymmer_flutter/package.json'));
const { PNG } = appRequire('pngjs');
const sharp = appRequire('sharp');

const SOURCE = path.resolve(__dirname, '../backup/assets/muscle_stills');
const GLB_FILE = path.resolve(__dirname, '../gymmer_flutter/assets/models/full-body.glb');
const PLATE_DIR = path.resolve(__dirname, '../backup/assets/muscle_plate');
const OUT = path.resolve(__dirname, '../gymmer_flutter/assets/muscle_layers');
const MUSCLES = [
  'Chest', 'Front Delt', 'Side Delt', 'Rear Delt', 'Biceps', 'Triceps',
  'Forearms', 'Traps', 'Rhomboids', 'Lats', 'Abs', 'Quads', 'Glutes',
  'Hamstrings', 'Calves',
];
const VIEWS = ['front', 'back'];
const SECONDARY_TINT = [242, 148, 120];
// Delts + abs read their real fibre colour from the pre-rendered colour plate
// (tools/render_color_plate.js), not a stretched GLB texture. Side Delt only
// claims pixels Front/Rear Delt did not, so it must be processed after them.
const PLATE_MUSCLES = new Set(['Front Delt', 'Rear Delt', 'Side Delt', 'Abs']);

function u(name) {
  return name.trim().replace(/\s+/g, '_');
}

function clamp(value) {
  return Math.max(0, Math.min(255, Math.round(value)));
}

function readPng(file) {
  return PNG.sync.read(fs.readFileSync(file));
}

function writePng(file, png) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, PNG.sync.write(png, { colorType: 6, inputColorType: 6 }));
}

function parseGlb(file) {
  const buf = fs.readFileSync(file);
  if (buf.toString('utf8', 0, 4) !== 'glTF') {
    throw new Error(`Not a GLB: ${file}`);
  }
  const jsonLength = buf.readUInt32LE(12);
  const jsonStart = 20;
  const json = JSON.parse(buf.slice(jsonStart, jsonStart + jsonLength).toString('utf8'));
  const binHeader = jsonStart + jsonLength;
  const binLength = buf.readUInt32LE(binHeader);
  const binStart = binHeader + 8;
  return { json, bin: buf.slice(binStart, binStart + binLength) };
}

async function loadOriginalTextures() {
  const { json, bin } = parseGlb(GLB_FILE);
  const textures = new Map();
  for (const muscle of MUSCLES) {
    if (PLATE_MUSCLES.has(muscle)) continue; // delts/abs come from the colour plate
    const materialName = `HL_${u(muscle)}`;
    const material = (json.materials || []).find((m) => m.name === materialName);
    const textureIndex = material?.pbrMetallicRoughness?.baseColorTexture?.index;
    if (textureIndex === undefined) continue;
    const texture = json.textures[textureIndex];
    const image = json.images[texture.source];
    const view = json.bufferViews[image.bufferView];
    const bytes = bin.slice(view.byteOffset || 0, (view.byteOffset || 0) + view.byteLength);
    const converted = await sharp(bytes)
      .ensureAlpha()
      .raw()
      .toBuffer({ resolveWithObject: true });
    textures.set(muscle, {
      data: converted.data,
      width: converted.info.width,
      height: converted.info.height,
      crop: textureCrop(converted.data, converted.info.width, converted.info.height),
    });
  }
  return textures;
}

function textureCrop(data, width, height) {
  let minX = width;
  let minY = height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];
      const max = Math.max(r, g, b);
      const min = Math.min(r, g, b);
      const chroma = max - min;
      const whiteTendonBand = r > 220 && g > 210 && b > 200 && chroma < 36;
      if (whiteTendonBand) continue;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    }
  }
  if (maxX < 0) return { minX: 0, minY: 0, maxX: width - 1, maxY: height - 1 };
  return { minX, minY, maxX, maxY };
}

function redStrength(data, i) {
  const r = data[i];
  const g = data[i + 1];
  const b = data[i + 2];
  const a = data[i + 3];
  if (a < 8) return 0;
  const dominance = r - Math.max(g, b);
  if (r < 70 || dominance < 24) return 0;
  if (r < g * 1.16 || r < b * 1.16) return 0;
  return Math.max(0, Math.min(255, Math.round(dominance * 3.2)));
}

function assertSameSize(images, view) {
  const first = images[0].png;
  for (const image of images) {
    if (image.png.width !== first.width || image.png.height !== first.height) {
      throw new Error(`${image.file} size differs from other ${view} stills`);
    }
  }
}

function neutralPixel(images, i, fallback) {
  for (const image of images) {
    if (image.png.data[i + 3] > 0 && redStrength(image.png.data, i) === 0) {
      return image.png.data;
    }
  }
  return fallback;
}

function muscleGray(data, i) {
  const lum = data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114;
  const gray = clamp(lum * 0.55 + 118);
  return [gray, gray, gray, data[i + 3]];
}

function buildBase(images, view) {
  const first = images[0].png;
  const base = new PNG({ width: first.width, height: first.height });
  for (let i = 0; i < first.data.length; i += 4) {
    const src = neutralPixel(images, i, first.data);
    if (src[i + 3] === 0) {
      base.data[i] = 0;
      base.data[i + 1] = 0;
      base.data[i + 2] = 0;
      base.data[i + 3] = 0;
      continue;
    }
    const gray = muscleGray(src, i);
    base.data[i] = gray[0];
    base.data[i + 1] = gray[1];
    base.data[i + 2] = gray[2];
    base.data[i + 3] = gray[3];
  }
  writePng(path.join(OUT, `base_${view}.png`), base);
  return base;
}

function maskBounds(image) {
  let minX = image.width;
  let minY = image.height;
  let maxX = -1;
  let maxY = -1;
  for (let y = 0; y < image.height; y++) {
    for (let x = 0; x < image.width; x++) {
      const i = (y * image.width + x) * 4;
      if (redStrength(image.data, i) === 0) continue;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    }
  }
  return maxX < 0 ? null : { minX, minY, maxX, maxY };
}

function texturePixel(texture, x, y, bounds) {
  if (!texture || !bounds) return null;
  const w = Math.max(1, bounds.maxX - bounds.minX + 1);
  const h = Math.max(1, bounds.maxY - bounds.minY + 1);
  const crop = texture.crop;
  const cropW = Math.max(1, crop.maxX - crop.minX + 1);
  const cropH = Math.max(1, crop.maxY - crop.minY + 1);
  const tx = Math.max(
    0,
    Math.min(
      texture.width - 1,
      crop.minX + Math.floor(((x - bounds.minX) / w) * cropW),
    ),
  );
  const ty = Math.max(
    0,
    Math.min(
      texture.height - 1,
      crop.minY + Math.floor(((y - bounds.minY) / h) * cropH),
    ),
  );
  const ti = (ty * texture.width + tx) * 4;
  return [texture.data[ti], texture.data[ti + 1], texture.data[ti + 2]];
}

function shadedPrimaryPixel(source, i, textureColor) {
  if (!textureColor) return [source.data[i], source.data[i + 1], source.data[i + 2]];
  const lum = source.data[i] * 0.299 + source.data[i + 1] * 0.587 + source.data[i + 2] * 0.114;
  const shade = Math.max(0.72, Math.min(1.22, lum / 170));
  return [
    clamp(textureColor[0] * shade),
    clamp(textureColor[1] * shade),
    clamp(textureColor[2] * shade),
  ];
}

function secondaryPixel(source, i) {
  const lum = source.data[i] * 0.299 + source.data[i + 1] * 0.587 + source.data[i + 2] * 0.114;
  const lineShade = Math.max(0.78, Math.min(1.15, lum / 176));
  const grayLine = clamp(lum * 0.38 + 110);
  return [
    clamp(SECONDARY_TINT[0] * lineShade * 0.78 + grayLine * 0.22),
    clamp(SECONDARY_TINT[1] * lineShade * 0.78 + grayLine * 0.22),
    clamp(SECONDARY_TINT[2] * lineShade * 0.78 + grayLine * 0.22),
  ];
}

function writeLayerPixel(layer, i, rgb, alpha) {
  layer.data[i] = rgb[0];
  layer.data[i + 1] = rgb[1];
  layer.data[i + 2] = rgb[2];
  layer.data[i + 3] = alpha;
}

function buildLayers(source, base, muscle, view, textures) {
  const primary = new PNG({ width: source.width, height: source.height });
  const secondary = new PNG({ width: source.width, height: source.height });
  const mask = new PNG({ width: source.width, height: source.height });
  const texture = textures.get(muscle);
  const bounds = maskBounds(source);
  let painted = 0;

  for (let y = 0; y < source.height; y++) {
    for (let x = 0; x < source.width; x++) {
      const i = (y * source.width + x) * 4;
      const alpha = redStrength(source.data, i);
      if (alpha === 0) continue;

      const original = texturePixel(texture, x, y, bounds);
      const primaryRgb = shadedPrimaryPixel(source, i, original);
      const secondaryRgb = secondaryPixel(source, i);
      writeLayerPixel(primary, i, primaryRgb, alpha);
      writeLayerPixel(secondary, i, secondaryRgb, alpha);

      const diff = Math.max(
        Math.abs(secondaryRgb[0] - base.data[i]),
        Math.abs(secondaryRgb[1] - base.data[i + 1]),
        Math.abs(secondaryRgb[2] - base.data[i + 2]),
      );
      const maskValue = clamp(Math.max(diff * 3, alpha));
      mask.data[i] = maskValue;
      mask.data[i + 1] = maskValue;
      mask.data[i + 2] = maskValue;
      mask.data[i + 3] = alpha;
      painted++;
    }
  }

  writePng(path.join(OUT, `${u(muscle)}_${view}.png`), primary);
  writePng(path.join(OUT, `${u(muscle)}_${view}_secondary.png`), secondary);
  writePng(path.join(OUT, `${u(muscle)}_${view}_mask.png`), mask);
  return painted;
}

// Boolean per-pixel mask (1 where the still's red highlight is present).
function boolMask(png) {
  const m = new Uint8Array(png.width * png.height);
  for (let p = 0, i = 0; p < m.length; p++, i += 4) m[p] = redStrength(png.data, i) > 0 ? 1 : 0;
  return m;
}

// Delts + abs: paint the muscle's real colour straight from the aligned colour
// plate, inside the part mask. `excludeBool` (Side Delt) drops pixels already
// claimed by Front/Rear Delt so the middle head only takes what is left.
function buildPlateLayers(source, base, plate, muscle, view, excludeBool) {
  if (plate.width !== source.width || plate.height !== source.height) {
    throw new Error(`colour plate ${view} size differs from the masks`);
  }
  const primary = new PNG({ width: source.width, height: source.height });
  const secondary = new PNG({ width: source.width, height: source.height });
  const mask = new PNG({ width: source.width, height: source.height });
  let painted = 0;

  for (let y = 0; y < source.height; y++) {
    for (let x = 0; x < source.width; x++) {
      const p = y * source.width + x;
      const i = p * 4;
      const alpha = redStrength(source.data, i);
      if (alpha === 0) continue;
      if (excludeBool && excludeBool[p]) continue; // Side Delt: leave Front/Rear pixels
      if (plate.data[i + 3] < 8) continue;         // no muscle on the plate here

      const primaryRgb = [plate.data[i], plate.data[i + 1], plate.data[i + 2]];
      const secondaryRgb = secondaryPixel(source, i);
      writeLayerPixel(primary, i, primaryRgb, alpha);
      writeLayerPixel(secondary, i, secondaryRgb, alpha);

      const diff = Math.max(
        Math.abs(secondaryRgb[0] - base.data[i]),
        Math.abs(secondaryRgb[1] - base.data[i + 1]),
        Math.abs(secondaryRgb[2] - base.data[i + 2]),
      );
      const maskValue = clamp(Math.max(diff * 3, alpha));
      mask.data[i] = maskValue;
      mask.data[i + 1] = maskValue;
      mask.data[i + 2] = maskValue;
      mask.data[i + 3] = alpha;
      painted++;
    }
  }

  writePng(path.join(OUT, `${u(muscle)}_${view}.png`), primary);
  writePng(path.join(OUT, `${u(muscle)}_${view}_secondary.png`), secondary);
  writePng(path.join(OUT, `${u(muscle)}_${view}_mask.png`), mask);
  return painted;
}

(async () => {
  const textures = await loadOriginalTextures();
  for (const view of VIEWS) {
    const images = MUSCLES.map((muscle) => {
      const file = path.join(SOURCE, `${u(muscle)}_${view}.png`);
      if (!fs.existsSync(file)) throw new Error(`Missing source still: ${file}`);
      return { muscle, file, png: readPng(file) };
    });
    assertSameSize(images, view);
    const base = buildBase(images, view);
    console.log(`base_${view}.png`);

    const plateFile = path.join(PLATE_DIR, `plate_${view}.png`);
    if (!fs.existsSync(plateFile)) {
      throw new Error(`Missing colour plate: ${plateFile}\nRun "npm run plate" first (tools/render_color_plate.js).`);
    }
    const plate = readPng(plateFile);
    const byMuscle = Object.fromEntries(images.map((im) => [im.muscle, im.png]));
    const frontBool = boolMask(byMuscle['Front Delt']);
    const rearBool = boolMask(byMuscle['Rear Delt']);
    const deltExclude = new Uint8Array(frontBool.length);
    for (let p = 0; p < deltExclude.length; p++) {
      deltExclude[p] = frontBool[p] || rearBool[p] ? 1 : 0;
    }

    for (const image of images) {
      let painted;
      let sourceLabel;
      if (PLATE_MUSCLES.has(image.muscle)) {
        const exclude = image.muscle === 'Side Delt' ? deltExclude : null;
        painted = buildPlateLayers(image.png, base, plate, image.muscle, view, exclude);
        sourceLabel = 'colour plate';
      } else {
        painted = buildLayers(image.png, base, image.muscle, view, textures);
        sourceLabel = textures.has(image.muscle) ? 'original texture diff' : 'render shading diff';
      }
      console.log(`${u(image.muscle)}_${view}.png (${painted} layer pixels, ${sourceLabel})`);
    }
  }
})().catch((error) => {
  console.error(error);
  process.exit(1);
});

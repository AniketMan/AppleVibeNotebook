# Figma (.fig) Asset Extraction and Naming Playbook

**Target Audience:** Autonomous AI Agents (Claude, etc.)
**Objective:** Extract raw image/GIF assets from a local `.fig` file, decode the proprietary Figma binary schema, and map the raw SHA-1 hash filenames back to their actual, human-readable Figma layer/frame names.

---

## 1. Architectural Context

A `.fig` file is not a standard image or vector file; it is a standard ZIP archive with a specific internal structure:
- `thumbnail.png`: A low-res preview of the file.
- `meta.json`: Basic metadata (canvas size, background color, export date).
- `images/`: A directory containing all raw raster assets (PNGs, JPEGs, GIFs). **Crucially, these files have no extensions and are named using their SHA-1 hash.**
- `canvas.fig`: The core proprietary binary file containing the entire node tree, layer names, vector data, and layout properties.

The `canvas.fig` binary is encoded using Figma's custom **Kiwi** schema. It consists of a header, followed by two zlib-compressed chunks:
1. The Kiwi schema definition.
2. The encoded node data (the actual document tree).

To get the real names of the images, you must decompress `canvas.fig`, compile the schema, decode the node data, walk the node tree to find image references (which are stored as hashes), and map those hashes back to the files in the `images/` directory.

---

## 2. Step-by-Step Execution Plan

### Step 2.1: Unzip the Archive
First, treat the `.fig` file as a ZIP and extract its contents.

```bash
mkdir -p ./figma_extract
unzip -o target_file.fig -d ./figma_extract
```

### Step 2.2: Identify and Rename Image Extensions
The files in the `images/` directory lack extensions. You must determine their MIME types and append the correct extensions (e.g., `.png`, `.gif`, `.jpg`) so they can be served or viewed properly.

```bash
cd ./figma_extract/images
for f in *; do
  # Skip if already has extension
  if [[ "$f" == *.* ]]; then continue; fi
  
  type=$(file -b --mime-type "$f")
  case "$type" in
    image/png) ext=".png";;
    image/jpeg) ext=".jpg";;
    image/gif) ext=".gif";;
    image/webp) ext=".webp";;
    image/svg+xml) ext=".svg";;
    *) ext=".bin";;
  esac
  
  mv "$f" "${f}${ext}"
done
```

### Step 2.3: Install Node.js Dependencies
To parse the `canvas.fig` binary, you need specific Node.js packages to handle the Kiwi schema and decompression.

```bash
cd ./figma_extract
npm init -y
npm install pako kiwi-schema fzstd
```

### Step 2.4: Execute the Deep Parser Script
Create and run the following Node.js script. This script handles the complex task of decoding the Kiwi binary, rebuilding the node hierarchy (to get full layer paths like `Page 1 / Frame A / Icon`), and deeply traversing every property of every node to find SHA-1 hashes that match the extracted images.

**Save this as `parse_figma.js`:**

```javascript
const fs = require('fs');
const pako = require('pako');
const kiwi = require('kiwi-schema');

// 1. Read the canvas.fig binary
const bytes = new Uint8Array(fs.readFileSync('./canvas.fig'));
const header = String.fromCharCode(...bytes.slice(0, 8));

if (header !== 'fig-kiwi' && header !== 'fig-jam.') {
  console.error('Invalid header');
  process.exit(1);
}

// 2. Extract compressed chunks
const view = new DataView(bytes.buffer);
const chunks = [];
let offset = 12;
while (offset < bytes.length) {
  const chunkLength = view.getUint32(offset, true);
  offset += 4;
  chunks.push(bytes.slice(offset, offset + chunkLength));
  offset += chunkLength;
}

let fzstd;
try { fzstd = require('fzstd'); } catch(e) { fzstd = null; }

function uncompressChunk(b) {
  try { return pako.inflateRaw(b); }
  catch (err) {
    if (fzstd) try { return fzstd.decompress(b); } catch {}
    throw err;
  }
}

// 3. Decode the schema and the node data
const encodedSchema = uncompressChunk(chunks[0]);
const encodedData = uncompressChunk(chunks[1]);
const schema = kiwi.compileSchema(kiwi.decodeBinarySchema(encodedSchema));
const { nodeChanges } = schema.decodeMessage(encodedData);

// 4. Build node map and hierarchy
const nodesMap = new Map();
for (const node of nodeChanges) {
  const { sessionID, localID } = node.guid;
  nodesMap.set(`${sessionID}:${localID}`, node);
}

for (const node of nodeChanges) {
  if (node.parentIndex) {
    const { sessionID, localID } = node.parentIndex.guid;
    const parent = nodesMap.get(`${sessionID}:${localID}`);
    if (parent) {
      parent.children = parent.children || [];
      parent.children.push(node);
    }
  }
}

// Helper to get full breadcrumb path of a node
function getNodePath(node) {
  const parts = [node.name || '(unnamed)'];
  let current = node;
  while (current.parentIndex) {
    const { sessionID, localID } = current.parentIndex.guid;
    const parent = nodesMap.get(`${sessionID}:${localID}`);
    if (parent && parent.name) {
      parts.unshift(parent.name);
      current = parent;
    } else break;
  }
  return parts.join(' / ');
}

// Helper to convert hash buffers to hex strings
function hashToHex(hashData) {
  if (!hashData) return null;
  if (Buffer.isBuffer(hashData)) return hashData.toString('hex');
  if (hashData instanceof Uint8Array || Array.isArray(hashData)) return Buffer.from(hashData).toString('hex');
  if (typeof hashData === 'string') return hashData;
  return null;
}

// 5. Deep recursive hash extractor
// Figma stores image hashes in various places (fillPaints, thumbnails, deep properties).
// We must walk the entire object tree of every node to ensure we don't miss GIFs or deeply nested assets.
function findAllHashes(obj, depth = 0) {
  const hashes = [];
  if (depth > 15 || !obj) return hashes;
  if (typeof obj !== 'object') return hashes;
  
  for (const [key, val] of Object.entries(obj)) {
    if (key === 'hash' && val) {
      const h = hashToHex(val);
      if (h && h.length === 40) hashes.push({ hash: h, key: key });
    }
    if (key === 'guid' || key === 'parentIndex') continue;
    if (Array.isArray(val)) {
      for (const item of val) hashes.push(...findAllHashes(item, depth + 1));
    } else if (typeof val === 'object' && val !== null) {
      hashes.push(...findAllHashes(val, depth + 1));
    }
  }
  return hashes;
}

// 6. Map all found hashes to their nodes
const hashToNodes = {};
for (const node of nodeChanges) {
  const name = node.name || '';
  const path = getNodePath(node);
  const allHashes = findAllHashes(node);
  const uniqueHashes = [...new Set(allHashes.map(h => h.hash))];
  
  for (const hash of uniqueHashes) {
    if (!hashToNodes[hash]) hashToNodes[hash] = [];
    hashToNodes[hash].push({ name, path });
  }
}

// 7. Cross-reference with actual files on disk
const imageDir = './images';
const diskFiles = fs.readdirSync(imageDir).filter(f => f.includes('.'));

const finalMapping = {};
for (const file of diskFiles) {
  const hash = file.split('.')[0]; // Remove extension to get raw hash
  if (hashToNodes[hash]) {
    const refs = hashToNodes[hash];
    // If an image is used in multiple places, pick the one with the deepest path (most specific)
    const best = refs.reduce((a, b) => a.path.length > b.path.length ? a : b);
    finalMapping[file] = {
      hash: hash,
      file: file,
      layerName: best.name,
      fullPath: best.path
    };
  } else {
    finalMapping[file] = { hash, file, layerName: 'Unknown', fullPath: 'Unknown' };
  }
}

// 8. Output the mapping
fs.writeFileSync('./asset_mapping.json', JSON.stringify(finalMapping, null, 2));
console.log('Successfully mapped assets to layer names. See asset_mapping.json');
```

**Run the script:**
```bash
node --max-old-space-size=4096 parse_figma.js
```
*(Note: `--max-old-space-size` is recommended as large `.fig` files can consume significant memory during schema decoding).*

---

## 3. Utilizing the Output

After running the pipeline, you will have:
1. An `images/` directory containing standard `.png`, `.gif`, etc. files.
2. An `asset_mapping.json` file that maps every `filename` to its `layerName` and `fullPath`.

**Example Output (`asset_mapping.json`):**
```json
{
  "03f8b379668326c4836bccb16b3656c0981f575b.png": {
    "hash": "03f8b379668326c4836bccb16b3656c0981f575b",
    "file": "03f8b379668326c4836bccb16b3656c0981f575b.png",
    "layerName": "Meta AI App Icon",
    "fullPath": "Document / Page 1 / Static / Meta AI App Icon / Content / Platform=iOS, Variant=Light / Image"
  }
}
```

From here, you can easily rename the files on disk to match their layer names, or serve them via a web UI using the JSON mapping as the data source. When renaming files, ensure you sanitize the `layerName` to remove illegal filesystem characters (e.g., `/`, `\`, `:`, `*`, `?`, `"`, `<`, `>`, `|`).

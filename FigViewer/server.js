/**
 * Fig Viewer - Standalone Local Server
 * 
 * A self-contained Express server that:
 *   1. Accepts .fig file uploads
 *   2. Extracts the ZIP contents
 *   3. Parses the Kiwi-encoded canvas.fig binary to get real Figma layer names
 *   4. Serves a gallery UI with search, filter, lightbox, and download
 *   5. Generates a ZIP of all assets with proper filenames
 * 
 * Dependencies: express, multer, pako, kiwi-schema, fzstd, archiver
 * 
 * Usage:
 *   node server.js
 *   Then open http://localhost:4000 in your browser
 */

const express = require("express");
const multer = require("multer");
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const archiver = require("archiver");
const pako = require("pako");
const kiwi = require("kiwi-schema");

// Optional: fzstd for zstd-compressed chunks (some newer .fig files)
let fzstd = null;
try { fzstd = require("fzstd"); } catch { /* optional */ }

// ─── Configuration ───────────────────────────────────────────────────────────

const PORT = process.env.PORT || 4000;
const UPLOAD_DIR = path.join(__dirname, ".uploads");
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

// ─── In-memory state (single file at a time) ────────────────────────────────

let currentResult = null;   // { assets, thumbnail, meta }
let currentExtractDir = null;
let currentFileName = "";
let isProcessing = false;

// ─── Fig Parser ──────────────────────────────────────────────────────────────

/**
 * Decompress a chunk using zlib (inflateRaw), falling back to zstd.
 */
function decompressChunk(data) {
  try { return pako.inflateRaw(data); }
  catch {
    if (fzstd) try { return fzstd.decompress(data); } catch { /* fall through */ }
    throw new Error("Failed to decompress chunk (tried zlib + zstd)");
  }
}

/**
 * Convert a hash value to a 40-char hex string.
 */
function hashToHex(hashData) {
  if (!hashData) return null;
  if (Buffer.isBuffer(hashData)) return hashData.toString("hex");
  if (hashData instanceof Uint8Array || Array.isArray(hashData)) return Buffer.from(hashData).toString("hex");
  if (typeof hashData === "string") return hashData;
  return null;
}

/**
 * Recursively walk an object tree to find all SHA-1 image hashes.
 * Depth-limited to 15 levels to prevent infinite recursion.
 */
function findAllHashes(obj, depth = 0) {
  const hashes = [];
  if (depth > 15 || !obj || typeof obj !== "object") return hashes;
  for (const [key, val] of Object.entries(obj)) {
    if (key === "hash" && val) {
      const h = hashToHex(val);
      if (h && h.length === 40) hashes.push(h);
    }
    if (key === "guid" || key === "parentIndex") continue;
    if (Array.isArray(val)) {
      for (const item of val) hashes.push(...findAllHashes(item, depth + 1));
    } else if (typeof val === "object" && val !== null) {
      hashes.push(...findAllHashes(val, depth + 1));
    }
  }
  return hashes;
}

/**
 * Detect file type from magic bytes and return extension.
 */
function detectExt(filePath) {
  try {
    const fd = fs.openSync(filePath, "r");
    const buf = Buffer.alloc(8);
    fs.readSync(fd, buf, 0, 8, 0);
    fs.closeSync(fd);
    if (buf.slice(0, 4).toString() === "GIF8") return "gif";
    if (buf[0] === 0x89 && buf.slice(1, 4).toString() === "PNG") return "png";
    if (buf[0] === 0xff && buf[1] === 0xd8) return "jpg";
    if (buf.slice(0, 4).toString() === "RIFF") return "webp";
  } catch { /* fall through */ }
  return "png";
}

/**
 * Parse canvas.fig binary and map image hashes to Figma layer names.
 */
function parseCanvasFig(canvasPath, imagesDir) {
  const bytes = new Uint8Array(fs.readFileSync(canvasPath));
  const header = String.fromCharCode(...bytes.slice(0, 8));
  if (header !== "fig-kiwi" && header !== "fig-jam.") {
    throw new Error(`Invalid canvas.fig header: "${header}"`);
  }

  // Extract compressed chunks
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const chunks = [];
  let offset = 12;
  while (offset < bytes.length) {
    const chunkLen = view.getUint32(offset, true);
    offset += 4;
    chunks.push(bytes.slice(offset, offset + chunkLen));
    offset += chunkLen;
  }
  if (chunks.length < 2) throw new Error(`Expected >= 2 chunks, got ${chunks.length}`);

  // Decompress and decode
  const schemaData = decompressChunk(chunks[0]);
  const nodeData = decompressChunk(chunks[1]);
  const schema = kiwi.compileSchema(kiwi.decodeBinarySchema(schemaData));
  const decoded = schema.decodeMessage(nodeData);
  const nodeChanges = decoded.nodeChanges || [];

  // Build node map for hierarchy
  const nodesMap = new Map();
  for (const node of nodeChanges) {
    if (!node.guid) continue;
    nodesMap.set(`${node.guid.sessionID}:${node.guid.localID}`, node);
  }

  // Build parent references
  for (const node of nodeChanges) {
    if (node.parentIndex?.guid) {
      const parentKey = `${node.parentIndex.guid.sessionID}:${node.parentIndex.guid.localID}`;
      const parent = nodesMap.get(parentKey);
      if (parent) {
        parent._children = parent._children || [];
        parent._children.push(node);
      }
    }
  }

  // Get full breadcrumb path
  function getNodePath(node) {
    const parts = [node.name || "(unnamed)"];
    let current = node;
    while (current.parentIndex?.guid) {
      const pKey = `${current.parentIndex.guid.sessionID}:${current.parentIndex.guid.localID}`;
      const parent = nodesMap.get(pKey);
      if (parent?.name) { parts.unshift(parent.name); current = parent; }
      else break;
    }
    return parts.join(" / ");
  }

  // Map hashes to nodes (deep traversal catches GIFs)
  const hashToNodeInfo = new Map();
  for (const node of nodeChanges) {
    const name = node.name || "";
    const nodePath = getNodePath(node);
    const allHashes = [...new Set(findAllHashes(node))];
    for (const hash of allHashes) {
      if (!hashToNodeInfo.has(hash)) hashToNodeInfo.set(hash, []);
      hashToNodeInfo.get(hash).push({ name, path: nodePath });
    }
  }

  // Cross-reference with disk files
  const diskFiles = fs.readdirSync(imagesDir);
  const assets = [];

  for (const file of diskFiles) {
    const filePath = path.join(imagesDir, file);
    const stat = fs.statSync(filePath);
    if (!stat.isFile()) continue;
    const hash = file.includes(".") ? file.split(".")[0] : file;
    if (hash.length !== 40) continue;
    const ext = file.includes(".") ? file.split(".").pop() : detectExt(filePath);
    const refs = hashToNodeInfo.get(hash);

    if (refs && refs.length > 0) {
      const best = refs.reduce((a, b) => (a.path.length > b.path.length ? a : b));
      const pathParts = best.path.split(" / ");
      const category = pathParts.length >= 3 ? pathParts[2] : "Uncategorized";
      let displayName = best.name;
      let variant = "";

      for (let i = pathParts.length - 1; i >= 0; i--) {
        const part = pathParts[i];
        if (part.includes("=") || part === "Content" || part === "Section" || part === "Animated Gif" || part === "Image") {
          if (part.includes("=") && !variant) variant = part;
          continue;
        }
        if (part !== "Document" && part !== best.name && !part.startsWith("Page")) {
          displayName = part + " - " + displayName;
          break;
        }
      }
      const variantParts = pathParts.filter(p => p.includes("="));
      if (variantParts.length > 0) variant = variantParts.join(", ");

      assets.push({ hash, ext, size: stat.size, displayName, category, variant, path: best.path, matched: true });
    } else {
      assets.push({ hash, ext, size: stat.size, displayName: hash.slice(0, 12) + "...", category: "Unmatched", variant: "", path: "", matched: false });
    }
  }
  return assets;
}

/**
 * Full pipeline: extract, rename, parse.
 */
function parseFigExtraction(extractDir) {
  const canvasPath = path.join(extractDir, "canvas.fig");
  const imagesDir = path.join(extractDir, "images");
  const thumbPath = path.join(extractDir, "thumbnail.png");
  const metaPath = path.join(extractDir, "meta.json");

  // Rename extensionless files
  if (fs.existsSync(imagesDir)) {
    for (const file of fs.readdirSync(imagesDir)) {
      if (file.includes(".")) continue;
      const filePath = path.join(imagesDir, file);
      const ext = detectExt(filePath);
      fs.renameSync(filePath, `${filePath}.${ext}`);
    }
  }

  let assets = [];
  if (fs.existsSync(canvasPath) && fs.existsSync(imagesDir)) {
    assets = parseCanvasFig(canvasPath, imagesDir);
  }

  let meta = {};
  if (fs.existsSync(metaPath)) {
    try { meta = JSON.parse(fs.readFileSync(metaPath, "utf-8")); } catch { /* ignore */ }
  }

  return { assets, thumbnail: fs.existsSync(thumbPath) ? thumbPath : null, meta };
}

// ─── Express App ─────────────────────────────────────────────────────────────

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

const upload = multer({
  dest: UPLOAD_DIR,
  limits: { fileSize: 2 * 1024 * 1024 * 1024 }, // 2 GB
  fileFilter: (_req, file, cb) => {
    if (file.originalname.endsWith(".fig")) cb(null, true);
    else cb(new Error("Only .fig files are accepted"));
  },
});

// ─── Helpers ─────────────────────────────────────────────────────────────────

function sanitizeHash(input) {
  const clean = input.replace(/[^0-9a-f]/g, "");
  return clean.length === 40 ? clean : null;
}

function sanitizeFileName(name) {
  return name.replace(/[<>:"/\\|?*]/g, "-").replace(/\s+/g, " ").trim();
}

function getCategoryCount(assets) {
  const counts = {};
  for (const a of assets) counts[a.category] = (counts[a.category] || 0) + 1;
  return counts;
}

// ─── Routes ──────────────────────────────────────────────────────────────────

// Upload a .fig file
app.post("/api/upload", upload.single("file"), async (req, res) => {
  if (isProcessing) return res.status(409).json({ error: "Already processing a file. Please wait." });
  if (!req.file) return res.status(400).json({ error: "No file uploaded" });

  isProcessing = true;
  const uploadedPath = req.file.path;
  currentFileName = req.file.originalname.replace(/\.fig$/, "");

  try {
    // Clean up previous extraction
    if (currentExtractDir && fs.existsSync(currentExtractDir)) {
      fs.rmSync(currentExtractDir, { recursive: true, force: true });
    }

    const extractDir = path.join(UPLOAD_DIR, `extract_${Date.now()}`);
    fs.mkdirSync(extractDir, { recursive: true });

    // Unzip (works on Windows with PowerShell, Linux with unzip)
    try {
      execSync(`unzip -o "${uploadedPath}" -d "${extractDir}"`, { timeout: 120000, maxBuffer: 10 * 1024 * 1024 });
    } catch {
      // Fallback for Windows: use PowerShell
      try {
        execSync(`powershell -Command "Expand-Archive -Path '${uploadedPath}' -DestinationPath '${extractDir}' -Force"`, { timeout: 120000 });
      } catch (e2) {
        throw new Error("Failed to extract .fig file. Ensure 'unzip' is installed (Linux/Mac) or PowerShell is available (Windows).");
      }
    }

    currentResult = parseFigExtraction(extractDir);
    currentExtractDir = extractDir;

    // Clean up uploaded zip
    try { fs.unlinkSync(uploadedPath); } catch { /* ignore */ }

    res.json({
      success: true,
      fileName: currentFileName,
      totalAssets: currentResult.assets.length,
      matched: currentResult.assets.filter(a => a.matched).length,
      unmatched: currentResult.assets.filter(a => !a.matched).length,
      categories: getCategoryCount(currentResult.assets),
      meta: currentResult.meta,
    });
  } catch (err) {
    console.error("Upload processing error:", err);
    res.status(500).json({ error: err.message || "Failed to process .fig file" });
  } finally {
    isProcessing = false;
  }
});

// Status check
app.get("/api/status", (_req, res) => {
  if (!currentResult) return res.json({ loaded: false, processing: isProcessing });
  res.json({
    loaded: true,
    processing: isProcessing,
    fileName: currentFileName,
    totalAssets: currentResult.assets.length,
    categories: getCategoryCount(currentResult.assets),
  });
});

// Get asset list (with filters)
app.get("/api/assets", (req, res) => {
  if (!currentResult) return res.status(404).json({ error: "No file loaded" });

  let results = currentResult.assets;
  const { category, ext, q, sort } = req.query;

  if (category && category !== "all") results = results.filter(a => a.category === category);
  if (ext && ext !== "all") results = results.filter(a => a.ext === ext);
  if (q) {
    const lower = q.toLowerCase();
    results = results.filter(a =>
      a.displayName.toLowerCase().includes(lower) ||
      a.variant.toLowerCase().includes(lower) ||
      a.path.toLowerCase().includes(lower)
    );
  }

  if (sort === "size") results = [...results].sort((a, b) => b.size - a.size);
  else if (sort === "category") results = [...results].sort((a, b) => a.category.localeCompare(b.category) || a.displayName.localeCompare(b.displayName));
  else results = [...results].sort((a, b) => a.displayName.localeCompare(b.displayName));

  res.json({ count: results.length, assets: results });
});

// Serve individual image
app.get("/api/assets/:hash", (req, res) => {
  if (!currentResult || !currentExtractDir) return res.status(404).json({ error: "No file loaded" });
  const hash = sanitizeHash(req.params.hash);
  if (!hash) return res.status(400).json({ error: "Invalid hash" });
  const asset = currentResult.assets.find(a => a.hash === hash);
  if (!asset) return res.status(404).json({ error: "Asset not found" });
  const filePath = path.join(currentExtractDir, "images", `${hash}.${asset.ext}`);
  if (!fs.existsSync(filePath)) return res.status(404).json({ error: "File not found" });

  const mimeMap = { png: "image/png", gif: "image/gif", jpg: "image/jpeg", webp: "image/webp" };
  res.setHeader("Content-Type", mimeMap[asset.ext] || "application/octet-stream");
  res.setHeader("Cache-Control", "public, max-age=3600");
  fs.createReadStream(filePath).pipe(res);
});

// Download individual image with proper filename
app.get("/api/download/:hash", (req, res) => {
  if (!currentResult || !currentExtractDir) return res.status(404).json({ error: "No file loaded" });
  const hash = sanitizeHash(req.params.hash);
  if (!hash) return res.status(400).json({ error: "Invalid hash" });
  const asset = currentResult.assets.find(a => a.hash === hash);
  if (!asset) return res.status(404).json({ error: "Asset not found" });
  const filePath = path.join(currentExtractDir, "images", `${hash}.${asset.ext}`);
  if (!fs.existsSync(filePath)) return res.status(404).json({ error: "File not found" });

  let fileName = sanitizeFileName(asset.displayName);
  if (asset.variant) fileName += ` [${sanitizeFileName(asset.variant)}]`;
  fileName += `.${asset.ext}`;

  res.setHeader("Content-Disposition", `attachment; filename="${fileName}"`);
  const mimeMap = { png: "image/png", gif: "image/gif", jpg: "image/jpeg", webp: "image/webp" };
  res.setHeader("Content-Type", mimeMap[asset.ext] || "application/octet-stream");
  fs.createReadStream(filePath).pipe(res);
});

// Download all as ZIP
app.get("/api/download-all", (_req, res) => {
  if (!currentResult || !currentExtractDir) return res.status(404).json({ error: "No file loaded" });

  const zipName = `${currentFileName || "figma-assets"}.zip`;
  res.setHeader("Content-Type", "application/zip");
  res.setHeader("Content-Disposition", `attachment; filename="${zipName}"`);

  const archive = archiver("zip", { zlib: { level: 1 } });
  archive.pipe(res);

  const usedNames = new Set();
  for (const asset of currentResult.assets) {
    const filePath = path.join(currentExtractDir, "images", `${asset.hash}.${asset.ext}`);
    if (!fs.existsSync(filePath)) continue;

    let baseName = sanitizeFileName(asset.displayName);
    if (asset.variant) baseName += ` [${sanitizeFileName(asset.variant)}]`;
    let fullName = `${sanitizeFileName(asset.category)}/${baseName}.${asset.ext}`;

    let counter = 1;
    while (usedNames.has(fullName.toLowerCase())) {
      fullName = `${sanitizeFileName(asset.category)}/${baseName} (${counter}).${asset.ext}`;
      counter++;
    }
    usedNames.add(fullName.toLowerCase());
    archive.file(filePath, { name: fullName });
  }
  archive.finalize();
});

// Thumbnail
app.get("/api/thumbnail", (_req, res) => {
  if (!currentResult?.thumbnail) return res.status(404).json({ error: "No thumbnail" });
  res.setHeader("Content-Type", "image/png");
  fs.createReadStream(currentResult.thumbnail).pipe(res);
});

// SPA fallback
app.get("*", (_req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

// ─── Start ───────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log("");
  console.log("  ╔══════════════════════════════════════╗");
  console.log("  ║         Fig Viewer is running         ║");
  console.log(`  ║   http://localhost:${PORT}              ║`);
  console.log("  ╚══════════════════════════════════════╝");
  console.log("");
  console.log("  Drop a .fig file in the browser to get started.");
  console.log("  Press Ctrl+C to stop the server.");
  console.log("");
});

/**
 * fig-parser.ts
 * 
 * Core parser for Figma .fig files.
 * 
 * A .fig file is a ZIP archive containing:
 *   - thumbnail.png: Low-res preview
 *   - meta.json: Canvas metadata
 *   - images/: Raw raster assets named by SHA-1 hash (no extensions)
 *   - canvas.fig: Proprietary Kiwi-encoded binary with the full node tree
 * 
 * The canvas.fig binary structure:
 *   - 8-byte header: "fig-kiwi" or "fig-jam."
 *   - 4-byte padding
 *   - N compressed chunks (each prefixed with 4-byte LE length):
 *     - Chunk 0: zlib-compressed Kiwi schema definition
 *     - Chunk 1: zlib-compressed encoded node data
 * 
 * This module decompresses the chunks, compiles the schema, decodes the
 * node tree, and walks every node to find image hash references. It then
 * maps those hashes back to the files in the images/ directory.
 */

import * as fs from "fs";
import * as path from "path";

// These packages are CommonJS. Using createRequire for ESM compatibility.
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const pako = require("pako");
const kiwi = require("kiwi-schema");

let fzstd: any = null;
try {
  fzstd = require("fzstd");
} catch {
  // fzstd is optional — only needed if Figma uses zstd compression
}

// ─── Types ───────────────────────────────────────────────────────────────────

export interface ParsedAsset {
  hash: string;        // SHA-1 hash (40 hex chars)
  ext: string;         // "png" | "gif" | "jpg" | "webp"
  size: number;        // File size in bytes
  displayName: string; // Human-readable name from Figma layer tree
  category: string;    // Top-level section name (e.g., "Animated", "Static")
  variant: string;     // Variant properties (e.g., "Size=Bold, Mode=Dark")
  path: string;        // Full breadcrumb path through the node tree
  matched: boolean;    // Whether this hash was found in the node tree
}

export interface ParseResult {
  assets: ParsedAsset[];
  thumbnail: string | null;  // Path to thumbnail.png if it exists
  meta: Record<string, any>; // Contents of meta.json
  nodeChanges?: any[];       // Raw Kiwi node tree for the renderer
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Attempt to decompress a chunk using zlib (inflateRaw) first,
 * falling back to zstd if available.
 */
function decompressChunk(data: Uint8Array): Uint8Array {
  try {
    return pako.inflateRaw(data);
  } catch {
    if (fzstd) {
      try {
        return fzstd.decompress(data);
      } catch { /* fall through */ }
    }
    throw new Error("Failed to decompress chunk (tried zlib + zstd)");
  }
}

/**
 * Convert a hash value (Buffer, Uint8Array, or string) to a 40-char hex string.
 */
function hashToHex(hashData: any): string | null {
  if (!hashData) return null;
  if (Buffer.isBuffer(hashData)) return hashData.toString("hex");
  if (hashData instanceof Uint8Array || Array.isArray(hashData)) {
    return Buffer.from(hashData).toString("hex");
  }
  if (typeof hashData === "string") return hashData;
  return null;
}

/**
 * Recursively walk an object tree to find all SHA-1 hashes.
 * Skips guid/parentIndex fields to avoid false positives.
 * Depth-limited to 15 levels to prevent infinite recursion.
 */
function findAllHashes(obj: any, depth = 0): string[] {
  const hashes: string[] = [];
  if (depth > 15 || !obj || typeof obj !== "object") return hashes;

  for (const [key, val] of Object.entries(obj)) {
    // "hash" key with a value that resolves to 40 hex chars = image reference
    if (key === "hash" && val) {
      const h = hashToHex(val);
      if (h && h.length === 40) hashes.push(h);
    }
    // Skip structural references (not image data)
    if (key === "guid" || key === "parentIndex") continue;
    if (Array.isArray(val)) {
      for (const item of val) {
        hashes.push(...findAllHashes(item, depth + 1));
      }
    } else if (typeof val === "object" && val !== null) {
      hashes.push(...findAllHashes(val, depth + 1));
    }
  }
  return hashes;
}

/**
 * Detect MIME type from file magic bytes and return extension.
 */
function detectExt(filePath: string): string {
  try {
    const fd = fs.openSync(filePath, "r");
    const buf = Buffer.alloc(8);
    fs.readSync(fd, buf, 0, 8, 0);
    fs.closeSync(fd);

    if (buf.slice(0, 4).toString() === "GIF8") return "gif";
    if (buf[0] === 0x89 && buf.slice(1, 4).toString() === "PNG") return "png";
    if (buf[0] === 0xff && buf[1] === 0xd8) return "jpg";
    if (buf.slice(0, 4).toString() === "RIFF" && buf.slice(8, 12)?.toString() === "WEBP") return "webp";
  } catch { /* fall through */ }
  return "png"; // default assumption
}

// ─── Main Parser ─────────────────────────────────────────────────────────────

/**
 * Parse a canvas.fig binary and return the node tree with image hash mappings.
 * 
 * @param canvasPath - Absolute path to the extracted canvas.fig file
 * @param imagesDir  - Absolute path to the extracted images/ directory
 * @returns Array of ParsedAsset objects
 */
export function parseCanvasFig(canvasPath: string, imagesDir: string): { assets: ParsedAsset[]; nodeChanges: any[] } {
  // 1. Read the binary
  const bytes = new Uint8Array(fs.readFileSync(canvasPath));
  const header = String.fromCharCode(...Array.from(bytes.slice(0, 8)));

  if (header !== "fig-kiwi" && header !== "fig-jam.") {
    throw new Error(`Invalid canvas.fig header: "${header}". Expected "fig-kiwi" or "fig-jam."`);
  }

  // 2. Extract compressed chunks
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const chunks: Uint8Array[] = [];
  let offset = 12; // skip 8-byte header + 4-byte padding

  while (offset < bytes.length) {
    const chunkLen = view.getUint32(offset, true); // little-endian
    offset += 4;
    chunks.push(bytes.slice(offset, offset + chunkLen));
    offset += chunkLen;
  }

  if (chunks.length < 2) {
    throw new Error(`Expected at least 2 chunks, got ${chunks.length}`);
  }

  // 3. Decompress and decode
  const schemaData = decompressChunk(chunks[0]);
  const nodeData = decompressChunk(chunks[1]);

  const schema = kiwi.compileSchema(kiwi.decodeBinarySchema(schemaData));
  const decoded = schema.decodeMessage(nodeData);
  const nodeChanges: any[] = decoded.nodeChanges || [];

  // 4. Build node map for hierarchy traversal
  const nodesMap = new Map<string, any>();
  for (const node of nodeChanges) {
    if (!node.guid) continue;
    const key = `${node.guid.sessionID}:${node.guid.localID}`;
    nodesMap.set(key, node);
  }

  // 5. Build parent references
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

  // 6. Helper: get full breadcrumb path for a node
  function getNodePath(node: any): string {
    const parts: string[] = [node.name || "(unnamed)"];
    let current = node;
    while (current.parentIndex?.guid) {
      const pKey = `${current.parentIndex.guid.sessionID}:${current.parentIndex.guid.localID}`;
      const parent = nodesMap.get(pKey);
      if (parent?.name) {
        parts.unshift(parent.name);
        current = parent;
      } else break;
    }
    return parts.join(" / ");
  }

  // 7. Map hashes to nodes (deep traversal catches GIFs too)
  const hashToNodeInfo = new Map<string, { name: string; path: string }[]>();

  for (const node of nodeChanges) {
    const name = node.name || "";
    const nodePath = getNodePath(node);
    const allHashes = Array.from(new Set(findAllHashes(node)));

    for (const hash of allHashes) {
      if (!hashToNodeInfo.has(hash)) hashToNodeInfo.set(hash, []);
      hashToNodeInfo.get(hash)!.push({ name, path: nodePath });
    }
  }

  // 8. Cross-reference with actual files on disk
  const diskFiles = fs.readdirSync(imagesDir);
  const assets: ParsedAsset[] = [];

  for (const file of diskFiles) {
    const filePath = path.join(imagesDir, file);
    const stat = fs.statSync(filePath);
    if (!stat.isFile()) continue;

    // Get the hash (filename without extension, or the raw filename)
    const hash = file.includes(".") ? file.split(".")[0] : file;
    if (hash.length !== 40) continue; // Skip non-hash files

    const ext = file.includes(".") ? file.split(".").pop()! : detectExt(filePath);
    const refs = hashToNodeInfo.get(hash);

    if (refs && refs.length > 0) {
      // Pick the most specific reference (deepest path)
      const best = refs.reduce((a, b) => (a.path.length > b.path.length ? a : b));
      const pathParts = best.path.split(" / ");

      // Extract category from the path (typically the 3rd level: Document / Page / Category / ...)
      const category = pathParts.length >= 3 ? pathParts[2] : "Uncategorized";

      // Extract display name: use the parent section name + the component name
      // Path example: Document / Page 1 / Animated / Non-Voice Animations / Content / Section / Non-Voice/Bounce (V4) / Size=Bold, Mode=Light / Animated Gif
      let displayName = best.name;
      let variant = "";

      // Walk up to find a meaningful parent name
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

      // Collect all variant-like parts from the path
      const variantParts = pathParts.filter(p => p.includes("="));
      if (variantParts.length > 0) variant = variantParts.join(", ");

      assets.push({
        hash,
        ext,
        size: stat.size,
        displayName,
        category,
        variant,
        path: best.path,
        matched: true,
      });
    } else {
      // Unmatched — still include it with hash as name
      assets.push({
        hash,
        ext,
        size: stat.size,
        displayName: hash.slice(0, 12) + "...",
        category: "Unmatched",
        variant: "",
        path: "",
        matched: false,
      });
    }
  }

  return { assets, nodeChanges };
}

/**
 * Full pipeline: given a directory where a .fig was extracted,
 * parse everything and return the complete result.
 */
export function parseFigExtraction(extractDir: string): ParseResult {
  const canvasPath = path.join(extractDir, "canvas.fig");
  const imagesDir = path.join(extractDir, "images");
  const thumbPath = path.join(extractDir, "thumbnail.png");
  const metaPath = path.join(extractDir, "meta.json");

  // Detect and rename extensionless files in images/
  if (fs.existsSync(imagesDir)) {
    for (const file of fs.readdirSync(imagesDir)) {
      if (file.includes(".")) continue; // Already has extension
      const filePath = path.join(imagesDir, file);
      const ext = detectExt(filePath);
      fs.renameSync(filePath, `${filePath}.${ext}`);
    }
  }

  let assets: ParsedAsset[] = [];
  let nodeChanges: any[] = [];
  if (fs.existsSync(canvasPath) && fs.existsSync(imagesDir)) {
    const parsed = parseCanvasFig(canvasPath, imagesDir);
    assets = parsed.assets;
    nodeChanges = parsed.nodeChanges;
  }

  let meta: Record<string, any> = {};
  if (fs.existsSync(metaPath)) {
    try {
      meta = JSON.parse(fs.readFileSync(metaPath, "utf-8"));
    } catch { /* ignore */ }
  }

  return {
    assets,
    thumbnail: fs.existsSync(thumbPath) ? thumbPath : null,
    meta,
    nodeChanges,
  };
}

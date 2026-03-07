/**
 * render-worker.ts
 * 
 * Worker thread that handles CPU-intensive Figma vector rendering.
 * Runs in a separate thread so the main Express server stays responsive.
 * 
 * Communication protocol (via parentPort):
 *   Main -> Worker: { type: 'start', canvasPath, imagesDir, scale }
 *   Worker -> Main: { type: 'progress', rendered, total }
 *   Worker -> Main: { type: 'frame', id, name, path, category, variant, buffer (as base64), size }
 *   Worker -> Main: { type: 'done', rendered, failed }
 *   Worker -> Main: { type: 'error', message }
 */

import { parentPort } from 'worker_threads';
import { FigmaRenderer } from './fig-renderer.js';
import * as fs from 'fs';
import * as path from 'path';

// CommonJS imports for the Kiwi parser
import { createRequire } from 'module';
const require = createRequire(import.meta.url);
const pako = require('pako');
const kiwi = require('kiwi-schema');

let fzstd: any = null;
try { fzstd = require('fzstd'); } catch { /* optional */ }

if (!parentPort) {
  throw new Error('render-worker.ts must be run as a Worker thread');
}

const port = parentPort;

/**
 * Decompress a chunk using zlib (inflateRaw) first, falling back to zstd.
 */
function decompressChunk(data: Uint8Array): Uint8Array {
  try {
    return pako.inflateRaw(data);
  } catch {
    if (fzstd) {
      try { return fzstd.decompress(data); } catch { /* fall through */ }
    }
    throw new Error('Failed to decompress chunk');
  }
}

/**
 * Parse the canvas.fig binary and return the raw node changes array.
 */
function parseCanvasBinary(canvasPath: string): any[] {
  const bytes = new Uint8Array(fs.readFileSync(canvasPath));
  const header = String.fromCharCode(...Array.from(bytes.slice(0, 8)));

  if (header !== 'fig-kiwi' && header !== 'fig-jam.') {
    throw new Error(`Invalid header: "${header}"`);
  }

  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const chunks: Uint8Array[] = [];
  let offset = 12;

  while (offset < bytes.length) {
    const chunkLen = view.getUint32(offset, true);
    offset += 4;
    chunks.push(bytes.slice(offset, offset + chunkLen));
    offset += chunkLen;
  }

  if (chunks.length < 2) throw new Error(`Expected 2+ chunks, got ${chunks.length}`);

  const schemaData = decompressChunk(chunks[0]);
  const nodeData = decompressChunk(chunks[1]);
  const schema = kiwi.compileSchema(kiwi.decodeBinarySchema(schemaData));
  const decoded = schema.decodeMessage(nodeData);

  return decoded.nodeChanges || [];
}

/**
 * Sanitize a filename by removing invalid characters.
 */
function sanitizeFileName(name: string): string {
  return name.replace(/[<>:"/\\|?*]/g, '-').replace(/\s+/g, ' ').trim();
}

// Listen for messages from the main thread
port.on('message', async (msg: any) => {
  if (msg.type !== 'start') return;

  const { canvasPath, imagesDir, scale } = msg;

  try {
    port.postMessage({ type: 'progress', rendered: 0, total: 0, status: 'Parsing node tree...' });

    // Parse the binary
    const nodeChanges = parseCanvasBinary(canvasPath);

    port.postMessage({ type: 'progress', rendered: 0, total: 0, status: 'Building render tree...' });

    // Initialize the renderer
    const renderer = new FigmaRenderer();
    renderer.init(nodeChanges, imagesDir, scale || 2);

    port.postMessage({ type: 'progress', rendered: 0, total: 0, status: 'Loading images...' });
    await renderer.preloadImages();

    // Get renderable frames
    const frames = renderer.getAllNamedFrames();
    const total = frames.length;

    port.postMessage({ type: 'progress', rendered: 0, total, status: `Rendering ${total} frames...` });

    let rendered = 0;
    let failed = 0;

    for (const frame of frames) {
      try {
        if (frame.width < 20 || frame.height < 20) continue;

        const frameId = `rendered_${sanitizeFileName(frame.name).replace(/\s+/g, '_')}_${rendered}`;
        const buffer = await renderer.renderNode(frame.node, 4096);

        // Extract category and variant from path
        const pathParts = frame.path.split(' / ');
        const category = pathParts.length >= 1 ? pathParts[0] : 'Rendered';
        const variantParts = pathParts.filter((p: string) => p.includes('='));
        const variant = variantParts.join(', ');

        // Send the rendered frame back to the main thread
        // Use base64 encoding to transfer the buffer across threads
        port.postMessage({
          type: 'frame',
          id: frameId,
          name: frame.name,
          path: frame.path,
          category,
          variant,
          buffer: buffer.toString('base64'),
          size: buffer.length,
          width: frame.width,
          height: frame.height,
        });

        rendered++;

        // Send progress update every 5 frames
        if (rendered % 5 === 0) {
          port.postMessage({ type: 'progress', rendered, total, status: `Rendered ${rendered}/${total}` });
        }
      } catch (err: any) {
        failed++;
        if (failed <= 5) {
          port.postMessage({ type: 'error', message: `Failed "${frame.name}": ${err.message}` });
        }
      }
    }

    port.postMessage({ type: 'done', rendered, failed });
  } catch (err: any) {
    port.postMessage({ type: 'error', message: err.message });
    port.postMessage({ type: 'done', rendered: 0, failed: 1 });
  }
});

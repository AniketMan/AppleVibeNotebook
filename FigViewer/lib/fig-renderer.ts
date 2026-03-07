/**
 * fig-renderer.ts
 * 
 * Server-side Figma node tree renderer using node-canvas (Cairo).
 * Interprets the parsed Kiwi node tree and draws vector compositions
 * (frames, shapes, text, gradients, effects) to raster PNG images.
 * 
 * RENDERING PIPELINE:
 *   1. Build parent-child hierarchy from flat node list
 *   2. Resolve INSTANCE nodes to their SYMBOL definitions
 *   3. For each target frame, recursively render children bottom-up
 *   4. Each node: apply transform -> draw fills -> draw children -> draw strokes -> apply effects
 *   5. Export as PNG buffer
 * 
 * SUPPORTED PRIMITIVES:
 *   - FRAME, SYMBOL, INSTANCE (containers with optional fill/clip)
 *   - ROUNDED_RECTANGLE (with per-corner radii)
 *   - ELLIPSE (with arcData for partial arcs)
 *   - TEXT (with font family, size, weight, alignment, color)
 *   - LINE (stroke only)
 *   - VECTOR (fillGeometry/strokeGeometry paths)
 * 
 * SUPPORTED FILLS:
 *   - SOLID (rgba color)
 *   - GRADIENT_LINEAR (color stops + 2x3 transform matrix)
 *   - IMAGE (hash lookup -> raster image composited into shape)
 * 
 * SUPPORTED EFFECTS:
 *   - DROP_SHADOW (offset, radius, color, spread)
 *   - BACKGROUND_BLUR / FOREGROUND_BLUR (approximated)
 * 
 * BLEND MODES:
 *   - NORMAL, SCREEN, SOFT_LIGHT (mapped to Canvas globalCompositeOperation)
 */

import { createCanvas, loadImage, type Canvas, type CanvasRenderingContext2D, type Image } from 'canvas';
import * as fs from 'fs';
import * as path from 'path';

// ============================================================
// TYPE DEFINITIONS
// ============================================================

/** Figma color in 0..1 float range */
interface FigColor {
  r: number;
  g: number;
  b: number;
  a: number;
}

/** 2x3 affine transform matrix */
interface FigTransform {
  m00: number;
  m01: number;
  m02: number;
  m10: number;
  m11: number;
  m12: number;
}

/** Node size */
interface FigSize {
  x: number;
  y: number;
}

/** Gradient stop */
interface GradientStop {
  color: FigColor;
  position: number;
}

/** Image hash (20-byte array or hex string) */
interface FigImageRef {
  hash: Uint8Array | number[] | Record<string, number>;
  name?: string;
}

/** Fill paint definition */
interface FigFillPaint {
  type: string;           // SOLID | IMAGE | GRADIENT_LINEAR
  color?: FigColor;
  opacity?: number;
  visible?: boolean;
  blendMode?: string;
  stops?: GradientStop[];
  transform?: FigTransform;
  image?: FigImageRef;
  animatedImage?: FigImageRef;
  imageThumbnail?: FigImageRef;
  imageScaleMode?: string;
  rotation?: number;
  scale?: number;
  originalImageWidth?: number;
  originalImageHeight?: number;
}

/** Stroke paint definition */
interface FigStrokePaint {
  type: string;
  color?: FigColor;
  opacity?: number;
  visible?: boolean;
  blendMode?: string;
}

/** Effect definition */
interface FigEffect {
  type: string;           // DROP_SHADOW | BACKGROUND_BLUR | FOREGROUND_BLUR
  offset?: { x: number; y: number };
  radius?: number;
  color?: FigColor;
  spread?: number;
  visible?: boolean;
  blendMode?: string;
  showShadowBehindNode?: boolean;
}

/** Arc data for ellipses */
interface ArcData {
  startingAngle: number;
  endingAngle: number;
  innerRadius: number;
}

/** GUID reference */
interface FigGuid {
  sessionID: number;
  localID: number;
}

/** Symbol data for INSTANCE nodes */
interface SymbolData {
  symbolID?: FigGuid;
  symbolOverrides?: any[];
  uniformScaleFactor?: number;
}

/** Parsed Figma node (subset of properties we care about) */
interface FigNode {
  guid?: FigGuid;
  parentIndex?: { guid?: FigGuid; position?: string };
  type?: string;
  name?: string;
  visible?: boolean;
  opacity?: number;
  size?: FigSize;
  transform?: FigTransform;
  fillPaints?: FigFillPaint[];
  strokePaints?: FigStrokePaint[];
  strokeWeight?: number;
  strokeAlign?: string;
  strokeJoin?: string;
  strokeCap?: string;
  effects?: FigEffect[];
  blendMode?: string;
  mask?: boolean;
  frameMaskDisabled?: boolean;
  // Corner radii
  cornerRadius?: number;
  rectangleTopLeftCornerRadius?: number;
  rectangleTopRightCornerRadius?: number;
  rectangleBottomLeftCornerRadius?: number;
  rectangleBottomRightCornerRadius?: number;
  // Text properties
  characters?: string;
  textData?: { characters?: string; lines?: any[] };
  fontSize?: number;
  fontFamily?: string;
  fontName?: { family?: string; style?: string; postscript?: string };
  fontWeight?: number;
  textAlignHorizontal?: string;
  textAlignVertical?: string;
  letterSpacing?: number;
  lineHeight?: any;
  textAutoResize?: string;
  // Arc data for ellipses
  arcData?: ArcData;
  // Vector data
  vectorData?: any;
  fillGeometry?: any[];
  strokeGeometry?: any[];
  // Symbol/Instance
  symbolData?: SymbolData;
  derivedSymbolData?: any[];
  // Auto-layout (stack)
  stackMode?: string;
  stackSpacing?: number;
  stackHorizontalPadding?: number;
  stackVerticalPadding?: number;
  stackPaddingRight?: number;
  stackPaddingBottom?: number;
  stackPrimarySizing?: string;
  stackChildAlignSelf?: string;
  // Internal: children populated during hierarchy build
  _children?: FigNode[];
  _key?: string;
}

// ============================================================
// UTILITY FUNCTIONS
// ============================================================

/**
 * Convert Figma color (0..1 floats) to CSS rgba string.
 * Applies optional opacity multiplier.
 */
function figColorToCSS(color: FigColor, opacity: number = 1): string {
  const r = Math.round(color.r * 255);
  const g = Math.round(color.g * 255);
  const b = Math.round(color.b * 255);
  const a = color.a * opacity;
  return `rgba(${r},${g},${b},${a})`;
}

/**
 * Convert a Figma image hash (various formats) to a 40-char hex string.
 */
function hashToHex(hash: any): string | null {
  if (!hash) return null;
  if (Buffer.isBuffer(hash)) return hash.toString('hex');
  if (hash instanceof Uint8Array) return Buffer.from(hash).toString('hex');
  if (Array.isArray(hash)) return Buffer.from(hash).toString('hex');
  if (typeof hash === 'string') return hash;
  // Handle {0: byte, 1: byte, ...} format
  if (typeof hash === 'object') {
    const keys = Object.keys(hash).map(Number).filter(k => !isNaN(k)).sort((a, b) => a - b);
    if (keys.length >= 20) {
      const bytes = keys.map(k => hash[k]);
      return Buffer.from(bytes).toString('hex');
    }
  }
  return null;
}

/**
 * Map Figma blend mode to Canvas globalCompositeOperation.
 */
function mapBlendMode(mode?: string): GlobalCompositeOperation {
  switch (mode) {
    case 'SCREEN': return 'screen';
    case 'SOFT_LIGHT': return 'soft-light';
    case 'MULTIPLY': return 'multiply';
    case 'OVERLAY': return 'overlay';
    case 'DARKEN': return 'darken';
    case 'LIGHTEN': return 'lighten';
    case 'COLOR_DODGE': return 'color-dodge';
    case 'COLOR_BURN': return 'color-burn';
    case 'HARD_LIGHT': return 'hard-light';
    case 'DIFFERENCE': return 'difference';
    case 'EXCLUSION': return 'exclusion';
    case 'HUE': return 'hue';
    case 'SATURATION': return 'saturation';
    case 'COLOR': return 'color';
    case 'LUMINOSITY': return 'luminosity';
    default: return 'source-over';
  }
}

// ============================================================
// RENDERER CLASS
// ============================================================

export class FigmaRenderer {
  private nodes: FigNode[] = [];
  private nodeMap: Map<string, FigNode> = new Map();
  private symbolMap: Map<string, FigNode> = new Map();
  private imageCache: Map<string, Image> = new Map();
  private imagesDir: string = '';
  private scale: number = 2; // Render at 2x for quality

  /**
   * Initialize the renderer with parsed nodes and the images directory path.
   * Builds the parent-child hierarchy and symbol lookup map.
   */
  init(nodes: FigNode[], imagesDir: string, scale: number = 2): void {
    this.nodes = nodes;
    this.imagesDir = imagesDir;
    this.scale = scale;

    // Build node map (guid key -> node)
    this.nodeMap.clear();
    this.symbolMap.clear();
    for (const node of nodes) {
      if (node.guid) {
        const key = `${node.guid.sessionID}:${node.guid.localID}`;
        node._key = key;
        this.nodeMap.set(key, node);
        // Index SYMBOL nodes for instance resolution
        if (node.type === 'SYMBOL') {
          this.symbolMap.set(key, node);
        }
      }
    }

    // Build parent-child hierarchy
    for (const node of nodes) {
      if (node.parentIndex?.guid) {
        const parentKey = `${node.parentIndex.guid.sessionID}:${node.parentIndex.guid.localID}`;
        const parent = this.nodeMap.get(parentKey);
        if (parent) {
          if (!parent._children) parent._children = [];
          parent._children.push(node);
        }
      }
    }
  }

  /**
   * Get all renderable frames (direct children of CANVAS nodes).
   * These are the top-level compositions that can be exported.
   */
  getRenderableFrames(): { node: FigNode; name: string; width: number; height: number }[] {
    const frames: { node: FigNode; name: string; width: number; height: number }[] = [];
    for (const node of this.nodes) {
      if (node.type === 'CANVAS' && node._children) {
        for (const child of node._children) {
          if (child.size) {
            frames.push({
              node: child,
              name: child.name || 'Unnamed',
              width: child.size.x,
              height: child.size.y,
            });
          }
        }
      }
    }
    return frames;
  }

  /**
   * Get all named frames/components at any depth that could be individually rendered.
   * Includes FRAME, SYMBOL nodes with meaningful names (not internal).
   */
  getAllNamedFrames(): { node: FigNode; name: string; path: string; width: number; height: number }[] {
    const results: { node: FigNode; name: string; path: string; width: number; height: number }[] = [];
    
    // Only walk top-level frames (depth 0-2 from CANVAS).
    // Depth 0 = direct children of CANVAS (category sections like "Animated", "Static")
    // Depth 1 = subsections ("Non-Voice Animations", "Voice Animations")
    // Depth 2 = actual design frames ("Search Input Lockup", "Meta AI Ring")
    // We render depth 2 frames. If a depth 0/1 frame is small enough, render it too.
    // Generic names that should inherit parent context for clarity
    const GENERIC_NAMES = new Set(['Content', 'Frame', 'Group', 'Container', 'Wrapper', 'Inner', 'Outer', 'Body']);
    
    const walk = (node: FigNode, pathParts: string[], depth: number) => {
      const currentPath = [...pathParts, node.name || 'Unnamed'].join(' / ');
      
      if (!node.size || !node.name) return;
      
      const w = node.size.x;
      const h = node.size.y;
      
      // Skip tiny nodes (internal components, spacers)
      if (w < 20 || h < 20) return;
      
      // Determine if this frame is a renderable design asset:
      // - Must be FRAME, SYMBOL, or INSTANCE type
      // - Must be at depth 2+ (actual design frames, not category containers)
      //   OR at any depth if it's reasonably sized and has fills
      // - Large frames (up to 16000x16000) are allowed at depth 2+ — they'll be
      //   scaled down during rendering via maxWidth
      const isFrameType = node.type === 'FRAME' || node.type === 'SYMBOL' || node.type === 'INSTANCE';
      
      if (isFrameType) {
        const isDesignFrame = depth >= 2 && w <= 16000 && h <= 16000;
        const hasOwnFills = node.fillPaints && node.fillPaints.length > 0;
        const isSmallWithFills = hasOwnFills && w <= 2000 && h <= 2000;
        
        if (isDesignFrame || isSmallWithFills) {
          // Use parent name for generic-named children (e.g., "Content" -> "Search Input Lockup / Content")
          let displayName = node.name || 'Unnamed';
          if (GENERIC_NAMES.has(displayName) && pathParts.length > 0) {
            const parentName = pathParts[pathParts.length - 1];
            displayName = `${parentName} / ${displayName}`;
          }
          
          results.push({
            node,
            name: displayName,
            path: currentPath,
            width: w,
            height: h,
          });
          // Don't recurse into rendered frames - we already got them
          return;
        }
      }

      // Continue walking into children (only for container-like nodes)
      if (node._children && depth < 4) {
        for (const child of node._children) {
          walk(child, [...pathParts, node.name || 'Unnamed'], depth + 1);
        }
      }
    };

    for (const node of this.nodes) {
      if (node.type === 'CANVAS' && node._children) {
        for (const child of node._children) {
          walk(child, [], 0);
        }
      }
    }

    return results;
  }

  /**
   * Pre-load all images from the images directory into memory.
   * This avoids repeated disk reads during rendering.
   */
  async preloadImages(): Promise<void> {
    if (!fs.existsSync(this.imagesDir)) return;
    
    const files = fs.readdirSync(this.imagesDir);
    for (const file of files) {
      // Extract hash from filename (remove extension)
      const hash = file.replace(/\.(png|gif|jpg|jpeg|webp)$/i, '');
      if (hash.length === 40 && !this.imageCache.has(hash)) {
        try {
          const imgPath = path.join(this.imagesDir, file);
          const img = await loadImage(imgPath);
          this.imageCache.set(hash, img);
        } catch (e) {
          // Skip unloadable images (e.g., animated GIFs may fail)
        }
      }
    }
  }

  /**
   * Render a specific node and all its descendants to a PNG buffer.
   * 
   * @param node - The root node to render
   * @param maxWidth - Optional max width to constrain output (will scale down)
   * @returns PNG buffer
   */
  async renderNode(node: FigNode, maxWidth?: number): Promise<Buffer> {
    if (!node.size) throw new Error('Node has no size');

    let renderScale = this.scale;
    const w = node.size.x;
    const h = node.size.y;

    // Constrain to maxWidth if specified
    if (maxWidth && w * renderScale > maxWidth) {
      renderScale = maxWidth / w;
    }

    const canvasW = Math.ceil(w * renderScale);
    const canvasH = Math.ceil(h * renderScale);

    // Safety: cap at 8192x8192 to avoid memory issues
    if (canvasW > 8192 || canvasH > 8192) {
      const constrainScale = Math.min(8192 / w, 8192 / h);
      renderScale = constrainScale;
    }

    const finalW = Math.ceil(w * renderScale);
    const finalH = Math.ceil(h * renderScale);

    const canvas = createCanvas(finalW, finalH);
    const ctx = canvas.getContext('2d');

    // Apply base scale
    ctx.scale(renderScale, renderScale);

    // Render the node tree
    await this.drawNode(ctx, node, 0, 0);

    return canvas.toBuffer('image/png');
  }

  /**
   * Core recursive rendering function.
   * Draws a node at the given position, then recurses into children.
   */
  private async drawNode(ctx: CanvasRenderingContext2D, node: FigNode, parentX: number, parentY: number): Promise<void> {
    // Skip invisible nodes
    if (node.visible === false) return;

    // Skip non-renderable types
    const renderableTypes = ['FRAME', 'SYMBOL', 'INSTANCE', 'ROUNDED_RECTANGLE', 'ELLIPSE', 'TEXT', 'LINE', 'VECTOR'];
    if (node.type && !renderableTypes.includes(node.type)) return;

    const size = node.size || { x: 0, y: 0 };
    const transform = node.transform;

    // Calculate position from transform
    let x = parentX;
    let y = parentY;
    if (transform) {
      x = parentX + transform.m02;
      y = parentY + transform.m12;
    }

    ctx.save();

    // Apply opacity
    if (node.opacity !== undefined && node.opacity < 1) {
      ctx.globalAlpha *= node.opacity;
    }

    // Apply blend mode
    if (node.blendMode) {
      ctx.globalCompositeOperation = mapBlendMode(node.blendMode);
    }

    // Apply full affine transform if it includes rotation/scale
    if (transform) {
      const hasRotation = Math.abs(transform.m01) > 0.001 || Math.abs(transform.m10) > 0.001;
      const hasScale = Math.abs(transform.m00 - 1) > 0.001 || Math.abs(transform.m11 - 1) > 0.001;
      if (hasRotation || hasScale) {
        // Translate to position, apply rotation/scale, then draw at origin
        ctx.translate(x, y);
        ctx.transform(transform.m00, transform.m10, transform.m01, transform.m11, 0, 0);
        x = 0;
        y = 0;
      }
    }

    // Apply clipping for frames (unless frameMaskDisabled)
    const shouldClip = (node.type === 'FRAME' || node.type === 'SYMBOL' || node.type === 'INSTANCE') 
                       && !node.frameMaskDisabled;

    // Check for mask nodes among children
    let maskNode: FigNode | null = null;
    if (node._children) {
      maskNode = node._children.find(c => c.mask === true) || null;
    }

    // TEXT nodes get special handling
    if (node.type === 'TEXT') {
      this.drawText(ctx, node, x, y);
      ctx.restore();
      return;
    }

    // Draw fills
    await this.drawFills(ctx, node, x, y, size.x, size.y);

    // Draw strokes
    this.drawStrokes(ctx, node, x, y, size.x, size.y);

    // Apply drop shadow effect (before children, behind the node)
    if (node.effects) {
      for (const effect of node.effects) {
        if (effect.type === 'DROP_SHADOW' && effect.visible !== false) {
          this.drawDropShadow(ctx, node, x, y, size.x, size.y, effect);
        }
      }
    }

    // Clip children to frame bounds
    if (shouldClip) {
      ctx.save();
      this.clipToShape(ctx, node, x, y, size.x, size.y);
    }

    // If there's a mask node, apply it as a clip path
    if (maskNode) {
      ctx.save();
      const maskTransform = maskNode.transform;
      const maskX = x + (maskTransform?.m02 || 0);
      const maskY = y + (maskTransform?.m12 || 0);
      const maskSize = maskNode.size || { x: 0, y: 0 };
      
      // Special handling for ellipse masks with inside strokes (creates ring clip)
      const sw = maskNode.strokeWeight || 0;
      if (maskNode.type === 'ELLIPSE' && sw > 0 && maskNode.strokeAlign === 'INSIDE') {
        // Create a ring-shaped clip: outer ellipse minus inner ellipse
        ctx.beginPath();
        const cx = maskX + maskSize.x / 2;
        const cy = maskY + maskSize.y / 2;
        const rx = maskSize.x / 2;
        const ry = maskSize.y / 2;
        ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
        const innerRx = Math.max(0, rx - sw);
        const innerRy = Math.max(0, ry - sw);
        if (innerRx > 0 && innerRy > 0) {
          ctx.ellipse(cx, cy, innerRx, innerRy, 0, Math.PI * 2, 0, true);
        }
        ctx.clip('evenodd');
      } else {
        this.clipToShape(ctx, maskNode, maskX, maskY, maskSize.x, maskSize.y);
      }
    }

    // Render children
    if (node._children) {
      // For INSTANCE nodes, resolve the symbol and render its children
      if (node.type === 'INSTANCE' && node.symbolData?.symbolID) {
        await this.drawInstanceChildren(ctx, node, x, y);
      } else {
        for (const child of node._children) {
          if (child.mask) continue; // Skip mask nodes (already applied)
          await this.drawNode(ctx, child, x, y);
        }
      }
    }

    if (maskNode) ctx.restore();
    if (shouldClip) ctx.restore();

    ctx.restore();
  }

  /**
   * Draw fills for a node (solid, gradient, image).
   */
  private async drawFills(ctx: CanvasRenderingContext2D, node: FigNode, x: number, y: number, w: number, h: number): Promise<void> {
    const fills = node.fillPaints || [];
    
    for (const fill of fills) {
      if (fill.visible === false) continue;

      const fillOpacity = fill.opacity ?? 1;
      
      ctx.save();
      if (fillOpacity < 1) {
        ctx.globalAlpha *= fillOpacity;
      }
      if (fill.blendMode) {
        ctx.globalCompositeOperation = mapBlendMode(fill.blendMode);
      }

      if (fill.type === 'SOLID' && fill.color) {
        // Solid color fill
        ctx.fillStyle = figColorToCSS(fill.color, 1);
        this.fillShape(ctx, node, x, y, w, h);

      } else if (fill.type === 'GRADIENT_LINEAR' && fill.stops) {
        // Linear gradient fill
        const grad = this.createLinearGradient(ctx, fill, x, y, w, h);
        if (grad) {
          ctx.fillStyle = grad;
          this.fillShape(ctx, node, x, y, w, h);
        }

      } else if (fill.type === 'IMAGE') {
        // Image fill
        await this.drawImageFill(ctx, node, fill, x, y, w, h);
      }

      ctx.restore();
    }
  }

  /**
   * Draw strokes for a node.
   */
  private drawStrokes(ctx: CanvasRenderingContext2D, node: FigNode, x: number, y: number, w: number, h: number): void {
    const strokes = node.strokePaints || [];
    if (strokes.length === 0) return;

    const strokeWeight = node.strokeWeight || 1;
    const strokeAlign = node.strokeAlign || 'CENTER';

    for (const stroke of strokes) {
      if (stroke.visible === false) continue;
      if (!stroke.color) continue;

      ctx.save();
      ctx.strokeStyle = figColorToCSS(stroke.color, stroke.opacity ?? 1);
      ctx.lineWidth = strokeWeight;
      ctx.lineJoin = (node.strokeJoin?.toLowerCase() as CanvasLineJoin) || 'miter';

      // Adjust for stroke alignment
      if (strokeAlign === 'INSIDE') {
        ctx.save();
        this.clipToShape(ctx, node, x, y, w, h);
        ctx.lineWidth = strokeWeight * 2; // Double width since half is clipped
        this.strokeShape(ctx, node, x, y, w, h);
        ctx.restore();
      } else if (strokeAlign === 'OUTSIDE') {
        // For outside, we'd need inverse clip - approximate with offset
        ctx.lineWidth = strokeWeight * 2;
        this.strokeShape(ctx, node, x, y, w, h);
      } else {
        this.strokeShape(ctx, node, x, y, w, h);
      }

      ctx.restore();
    }
  }

  /**
   * Fill the shape defined by the node type.
   */
  private fillShape(ctx: CanvasRenderingContext2D, node: FigNode, x: number, y: number, w: number, h: number): void {
    ctx.beginPath();
    this.tracePath(ctx, node, x, y, w, h);
    ctx.fill();
  }

  /**
   * Stroke the shape defined by the node type.
   */
  private strokeShape(ctx: CanvasRenderingContext2D, node: FigNode, x: number, y: number, w: number, h: number): void {
    ctx.beginPath();
    this.tracePath(ctx, node, x, y, w, h);
    ctx.stroke();
  }

  /**
   * Clip to the shape defined by the node type.
   */
  private clipToShape(ctx: CanvasRenderingContext2D, node: FigNode, x: number, y: number, w: number, h: number): void {
    ctx.beginPath();
    this.tracePath(ctx, node, x, y, w, h);
    ctx.clip();
  }

  /**
   * Trace the path for a node's shape onto the canvas context.
   * Handles ROUNDED_RECTANGLE, ELLIPSE, and default rectangle.
   */
  private tracePath(ctx: CanvasRenderingContext2D, node: FigNode, x: number, y: number, w: number, h: number): void {
    if (node.type === 'ROUNDED_RECTANGLE' || this.hasCornerRadii(node)) {
      // Rounded rectangle with per-corner radii
      const tl = node.rectangleTopLeftCornerRadius || node.cornerRadius || 0;
      const tr = node.rectangleTopRightCornerRadius || node.cornerRadius || 0;
      const br = node.rectangleBottomRightCornerRadius || node.cornerRadius || 0;
      const bl = node.rectangleBottomLeftCornerRadius || node.cornerRadius || 0;

      // Clamp radii to half the smallest dimension
      const maxR = Math.min(w, h) / 2;
      const rtl = Math.min(tl, maxR);
      const rtr = Math.min(tr, maxR);
      const rbr = Math.min(br, maxR);
      const rbl = Math.min(bl, maxR);

      ctx.moveTo(x + rtl, y);
      ctx.lineTo(x + w - rtr, y);
      if (rtr > 0) ctx.arcTo(x + w, y, x + w, y + rtr, rtr);
      ctx.lineTo(x + w, y + h - rbr);
      if (rbr > 0) ctx.arcTo(x + w, y + h, x + w - rbr, y + h, rbr);
      ctx.lineTo(x + rbl, y + h);
      if (rbl > 0) ctx.arcTo(x, y + h, x, y + h - rbl, rbl);
      ctx.lineTo(x, y + rtl);
      if (rtl > 0) ctx.arcTo(x, y, x + rtl, y, rtl);
      ctx.closePath();

    } else if (node.type === 'ELLIPSE') {
      // Ellipse (or arc)
      const cx = x + w / 2;
      const cy = y + h / 2;
      const rx = w / 2;
      const ry = h / 2;

      if (node.arcData) {
        const start = node.arcData.startingAngle;
        const end = node.arcData.endingAngle;
        ctx.ellipse(cx, cy, rx, ry, 0, start, end);
        if (node.arcData.innerRadius > 0) {
          // Ring shape
          const irx = rx * node.arcData.innerRadius;
          const iry = ry * node.arcData.innerRadius;
          ctx.ellipse(cx, cy, irx, iry, 0, end, start, true);
        }
      } else {
        ctx.ellipse(cx, cy, rx, ry, 0, 0, Math.PI * 2);
      }
      ctx.closePath();

    } else if (node.type === 'LINE') {
      // Line from (x,y) to (x+w, y)
      ctx.moveTo(x, y);
      ctx.lineTo(x + w, y);

    } else {
      // Default: plain rectangle
      ctx.rect(x, y, w, h);
    }
  }

  /**
   * Check if a node has any corner radius properties set.
   */
  private hasCornerRadii(node: FigNode): boolean {
    return !!(node.cornerRadius || node.rectangleTopLeftCornerRadius || 
              node.rectangleTopRightCornerRadius || node.rectangleBottomLeftCornerRadius || 
              node.rectangleBottomRightCornerRadius);
  }

  /**
   * Create a Canvas linear gradient from Figma gradient definition.
   * The Figma gradient transform maps from a unit square [0,1]x[0,1] 
   * to the actual gradient line.
   */
  private createLinearGradient(
    ctx: CanvasRenderingContext2D,
    fill: FigFillPaint,
    x: number, y: number, w: number, h: number
  ): CanvasGradient | null {
    if (!fill.stops || !fill.transform) return null;

    const t = fill.transform;
    
    // Figma gradient transform: maps unit square to gradient space
    // Start point is at (0, 0.5) in unit space, end point at (1, 0.5)
    // Transform these through the matrix, then scale to node size
    const x0 = (t.m00 * 0 + t.m01 * 0.5 + t.m02) * w + x;
    const y0 = (t.m10 * 0 + t.m11 * 0.5 + t.m12) * h + y;
    const x1 = (t.m00 * 1 + t.m01 * 0.5 + t.m02) * w + x;
    const y1 = (t.m10 * 1 + t.m11 * 0.5 + t.m12) * h + y;

    const grad = ctx.createLinearGradient(x0, y0, x1, y1);
    for (const stop of fill.stops) {
      grad.addColorStop(stop.position, figColorToCSS(stop.color));
    }
    return grad;
  }

  /**
   * Draw an image fill within a node's shape.
   * Looks up the image by hash from the preloaded cache.
   */
  private async drawImageFill(
    ctx: CanvasRenderingContext2D,
    node: FigNode,
    fill: FigFillPaint,
    x: number, y: number, w: number, h: number
  ): Promise<void> {
    // Try multiple hash sources: image, animatedImage, imageThumbnail
    const hashSources = [fill.image, fill.imageThumbnail, fill.animatedImage];
    let img: Image | undefined;

    for (const src of hashSources) {
      if (!src?.hash) continue;
      const hex = hashToHex(src.hash);
      if (hex && this.imageCache.has(hex)) {
        img = this.imageCache.get(hex);
        break;
      }
    }

    if (!img) return;

    ctx.save();
    
    // Clip to the node shape
    ctx.beginPath();
    this.tracePath(ctx, node, x, y, w, h);
    ctx.clip();

    const scaleMode = fill.imageScaleMode || 'FILL';
    const imgW = img.width;
    const imgH = img.height;

    if (scaleMode === 'FILL') {
      // Scale to cover the entire shape, maintaining aspect ratio
      const scaleX = w / imgW;
      const scaleY = h / imgH;
      const scale = Math.max(scaleX, scaleY);
      const drawW = imgW * scale;
      const drawH = imgH * scale;
      const drawX = x + (w - drawW) / 2;
      const drawY = y + (h - drawH) / 2;
      ctx.drawImage(img, drawX, drawY, drawW, drawH);
    } else if (scaleMode === 'FIT') {
      // Scale to fit within the shape, maintaining aspect ratio
      const scaleX = w / imgW;
      const scaleY = h / imgH;
      const scale = Math.min(scaleX, scaleY);
      const drawW = imgW * scale;
      const drawH = imgH * scale;
      const drawX = x + (w - drawW) / 2;
      const drawY = y + (h - drawH) / 2;
      ctx.drawImage(img, drawX, drawY, drawW, drawH);
    } else {
      // Default: stretch to fill
      ctx.drawImage(img, x, y, w, h);
    }

    ctx.restore();
  }

  /**
   * Draw a drop shadow effect.
   */
  private drawDropShadow(
    ctx: CanvasRenderingContext2D,
    node: FigNode,
    x: number, y: number, w: number, h: number,
    effect: FigEffect
  ): void {
    if (!effect.color || !effect.offset) return;

    ctx.save();
    ctx.shadowColor = figColorToCSS(effect.color);
    ctx.shadowBlur = effect.radius || 0;
    ctx.shadowOffsetX = effect.offset.x;
    ctx.shadowOffsetY = effect.offset.y;

    // Draw the shape to cast the shadow
    ctx.fillStyle = 'rgba(0,0,0,1)';
    ctx.beginPath();
    this.tracePath(ctx, node, x, y, w, h);
    ctx.fill();

    ctx.restore();
  }

  /**
   * Render an INSTANCE node by resolving its referenced SYMBOL.
   * Clones the symbol's children and applies any overrides.
   */
  private async drawInstanceChildren(ctx: CanvasRenderingContext2D, instance: FigNode, x: number, y: number): Promise<void> {
    const symbolID = instance.symbolData?.symbolID;
    if (!symbolID) {
      // No symbol reference, just render own children
      if (instance._children) {
        for (const child of instance._children) {
          if (child.mask) continue;
          await this.drawNode(ctx, child, x, y);
        }
      }
      return;
    }

    const symbolKey = `${symbolID.sessionID}:${symbolID.localID}`;
    const symbol = this.symbolMap.get(symbolKey);

    if (symbol && symbol._children) {
      // Render the symbol's children within the instance's bounds
      // Apply scale factor if the instance size differs from symbol size
      const symbolSize = symbol.size || { x: 1, y: 1 };
      const instanceSize = instance.size || symbolSize;

      const scaleX = instanceSize.x / (symbolSize.x || 1);
      const scaleY = instanceSize.y / (symbolSize.y || 1);

      if (Math.abs(scaleX - 1) > 0.01 || Math.abs(scaleY - 1) > 0.01) {
        ctx.save();
        ctx.translate(x, y);
        ctx.scale(scaleX, scaleY);
        for (const child of symbol._children) {
          await this.drawNode(ctx, child, 0, 0);
        }
        ctx.restore();
      } else {
        for (const child of symbol._children) {
          await this.drawNode(ctx, child, x, y);
        }
      }
    }

    // Also render the instance's own children (overrides)
    if (instance._children) {
      for (const child of instance._children) {
        if (child.mask) continue;
        await this.drawNode(ctx, child, x, y);
      }
    }
  }

  /**
   * Draw a TEXT node.
   * Uses system fonts as Figma fonts may not be available.
   */
  private drawText(ctx: CanvasRenderingContext2D, node: FigNode, x: number, y: number): void {
    // Figma stores text in textData.characters, not directly on node.characters
    const chars = node.textData?.characters || node.characters;
    if (!chars) return;

    const fontSize = node.fontSize || 14;
    // Figma stores font info in fontName.family, not fontFamily
    const fontFamily = node.fontName?.family || node.fontFamily || 'Helvetica';
    const align = node.textAlignHorizontal || 'LEFT';

    // Derive font weight from fontName.style or fontWeight
    let fontWeight = node.fontWeight || 400;
    if (node.fontName?.style) {
      const style = node.fontName.style.toLowerCase();
      if (style.includes('bold') || style.includes('black')) fontWeight = 700;
      else if (style.includes('semibold') || style.includes('demibold')) fontWeight = 600;
      else if (style.includes('medium')) fontWeight = 500;
      else if (style.includes('light') || style.includes('thin')) fontWeight = 300;
    }

    // Map font weight to CSS weight keyword
    let weightStr = 'normal';
    if (fontWeight >= 700) weightStr = 'bold';
    else if (fontWeight >= 500) weightStr = '500';

    // Use fallback system fonts since Figma proprietary fonts won't be available
    ctx.font = `${weightStr} ${fontSize}px "Helvetica Neue", Helvetica, Arial, sans-serif`;

    // Set text alignment
    if (align === 'CENTER') ctx.textAlign = 'center';
    else if (align === 'RIGHT') ctx.textAlign = 'right';
    else ctx.textAlign = 'left';

    ctx.textBaseline = 'top';

    // Get fill color for text
    const fills = node.fillPaints || [];
    const solidFill = fills.find(f => f.type === 'SOLID' && f.visible !== false);
    if (solidFill?.color) {
      ctx.fillStyle = figColorToCSS(solidFill.color, solidFill.opacity ?? 1);
    } else {
      ctx.fillStyle = 'rgba(0,0,0,1)';
    }

    // Calculate text position based on alignment
    let textX = x;
    if (align === 'CENTER' && node.size) textX = x + node.size.x / 2;
    else if (align === 'RIGHT' && node.size) textX = x + node.size.x;

    // Handle multi-line text
    const lines = chars.split('\n');
    const lineH = node.lineHeight?.value || fontSize * 1.2;
    
    for (let i = 0; i < lines.length; i++) {
      ctx.fillText(lines[i], textX, y + i * lineH);
    }
  }
}

/**
 * Convenience function: render all exportable frames from a parsed .fig extraction.
 * Returns an array of {name, path, buffer} for each rendered frame.
 */
export async function renderAllFrames(
  nodes: FigNode[],
  imagesDir: string,
  options: { scale?: number; maxWidth?: number } = {}
): Promise<{ name: string; path: string; width: number; height: number; buffer: Buffer }[]> {
  const renderer = new FigmaRenderer();
  renderer.init(nodes, imagesDir, options.scale || 2);
  await renderer.preloadImages();

  const frames = renderer.getAllNamedFrames();
  const results: { name: string; path: string; width: number; height: number; buffer: Buffer }[] = [];

  for (const frame of frames) {
    try {
      const buffer = await renderer.renderNode(frame.node, options.maxWidth);
      results.push({
        name: frame.name,
        path: frame.path,
        width: frame.width,
        height: frame.height,
        buffer,
      });
    } catch (e) {
      console.error(`Failed to render frame "${frame.name}":`, e);
    }
  }

  return results;
}

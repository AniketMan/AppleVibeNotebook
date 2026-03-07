# Fig Viewer

A standalone tool to open `.fig` (Figma) files, extract all embedded assets, and browse them with their real Figma layer names.

## Requirements

- **Node.js** 18+ (https://nodejs.org)
- **unzip** (Linux/Mac) or **PowerShell** (Windows, built-in)

## Quick Start

### Windows

Double-click `FigViewer.bat`. It will install dependencies on first run, start the server, and open your browser.

### Mac / Linux

```bash
npm install --production
node server.js
```

Then open http://localhost:4000

## Features

- Upload any `.fig` file (up to 2 GB)
- Extracts all embedded images (PNG, GIF, JPG, WebP)
- Parses the proprietary Kiwi binary to recover real Figma layer names
- Grid and list view with search, category filter, and type filter
- Lightbox with arrow key navigation
- Download individual assets with descriptive filenames
- Download all assets as a ZIP organized by category

## How It Works

A `.fig` file is a ZIP archive containing:

1. `meta.json` - File metadata and export info
2. `thumbnail.png` - Canvas preview
3. `canvas.fig` - Kiwi-encoded binary with the full node tree
4. `images/` - Raw image blobs named by SHA-1 hash

The parser decompresses the Kiwi binary, decodes the schema, walks all nodes to find image hash references (including deep-nested GIF references), and maps each hash back to its Figma layer name, variant properties, and category.

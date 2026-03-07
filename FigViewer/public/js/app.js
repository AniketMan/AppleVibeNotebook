/* ─── Fig Viewer - Frontend App ────────────────────────────────────────────── */

(function () {
  "use strict";

  // ─── State ───────────────────────────────────────────────────────────────
  let assets = [];
  let filteredAssets = [];
  let viewMode = "grid"; // "grid" | "list"
  let lightboxIndex = -1;

  // ─── DOM refs ────────────────────────────────────────────────────────────
  const $ = (sel) => document.querySelector(sel);
  const uploadScreen = $("#upload-screen");
  const galleryScreen = $("#gallery-screen");
  const dropzone = $("#dropzone");
  const fileInput = $("#file-input");
  const progressContainer = $("#upload-progress");
  const progressFill = $("#progress-fill");
  const progressText = $("#progress-text");
  const uploadError = $("#upload-error");
  const gallery = $("#gallery");
  const searchInput = $("#search-input");
  const filterCategory = $("#filter-category");
  const filterType = $("#filter-type");
  const sortBy = $("#sort-by");
  const assetCount = $("#asset-count");
  const fileName = $("#file-name");
  const fileCount = $("#file-count");
  const lightbox = $("#lightbox");
  const lightboxImg = $("#lightbox-img");
  const lightboxName = $("#lightbox-name");
  const lightboxPath = $("#lightbox-path");
  const lightboxMeta = $("#lightbox-meta");

  // ─── Upload Flow ─────────────────────────────────────────────────────────

  // Check if data is already loaded
  fetch("/api/status")
    .then((r) => r.json())
    .then((data) => {
      if (data.loaded) {
        showGallery(data.fileName, data.totalAssets, data.categories);
        loadAssets();
      }
    })
    .catch(() => {});

  dropzone.addEventListener("click", () => fileInput.click());
  dropzone.addEventListener("dragover", (e) => { e.preventDefault(); dropzone.classList.add("drag-over"); });
  dropzone.addEventListener("dragleave", () => dropzone.classList.remove("drag-over"));
  dropzone.addEventListener("drop", (e) => {
    e.preventDefault();
    dropzone.classList.remove("drag-over");
    const file = e.dataTransfer.files[0];
    if (file && file.name.endsWith(".fig")) uploadFile(file);
    else showError("Please drop a .fig file");
  });
  fileInput.addEventListener("change", () => {
    if (fileInput.files[0]) uploadFile(fileInput.files[0]);
  });

  function uploadFile(file) {
    uploadError.classList.add("hidden");
    progressContainer.classList.remove("hidden");
    progressFill.style.width = "0%";
    progressText.textContent = "Uploading...";

    const xhr = new XMLHttpRequest();
    const formData = new FormData();
    formData.append("file", file);

    xhr.upload.addEventListener("progress", (e) => {
      if (e.lengthComputable) {
        const pct = Math.round((e.loaded / e.total) * 100);
        progressFill.style.width = pct + "%";
        if (pct >= 100) progressText.textContent = "Processing .fig file...";
        else progressText.textContent = `Uploading... ${pct}%`;
      }
    });

    xhr.addEventListener("load", () => {
      if (xhr.status === 200) {
        const data = JSON.parse(xhr.responseText);
        if (data.success) {
          progressText.textContent = "Done!";
          setTimeout(() => {
            showGallery(data.fileName, data.totalAssets, data.categories);
            loadAssets();
          }, 300);
        } else {
          showError(data.error || "Upload failed");
        }
      } else {
        try {
          const err = JSON.parse(xhr.responseText);
          showError(err.error || `Upload failed (${xhr.status})`);
        } catch {
          showError(`Upload failed (${xhr.status})`);
        }
      }
    });

    xhr.addEventListener("error", () => showError("Network error during upload"));
    xhr.open("POST", "/api/upload");
    xhr.send(formData);
  }

  function showError(msg) {
    progressContainer.classList.add("hidden");
    uploadError.textContent = msg;
    uploadError.classList.remove("hidden");
  }

  // ─── Gallery ─────────────────────────────────────────────────────────────

  function showGallery(name, count, categories) {
    uploadScreen.classList.remove("active");
    galleryScreen.classList.add("active");
    fileName.textContent = name + ".fig";
    fileCount.textContent = count + " assets";

    // Populate category filter
    filterCategory.innerHTML = '<option value="all">All Categories</option>';
    if (categories) {
      for (const [cat, cnt] of Object.entries(categories).sort()) {
        const opt = document.createElement("option");
        opt.value = cat;
        opt.textContent = `${cat} (${cnt})`;
        filterCategory.appendChild(opt);
      }
    }
  }

  function loadAssets() {
    fetch("/api/assets?sort=name")
      .then((r) => r.json())
      .then((data) => {
        assets = data.assets || [];
        filteredAssets = [...assets];
        renderGallery();
      });
  }

  function applyFilters() {
    const q = searchInput.value.toLowerCase().trim();
    const cat = filterCategory.value;
    const type = filterType.value;
    const sort = sortBy.value;

    filteredAssets = assets.filter((a) => {
      if (cat !== "all" && a.category !== cat) return false;
      if (type !== "all" && a.ext !== type) return false;
      if (q && !a.displayName.toLowerCase().includes(q) && !a.variant.toLowerCase().includes(q) && !a.path.toLowerCase().includes(q)) return false;
      return true;
    });

    if (sort === "size") filteredAssets.sort((a, b) => b.size - a.size);
    else if (sort === "category") filteredAssets.sort((a, b) => a.category.localeCompare(b.category) || a.displayName.localeCompare(b.displayName));
    else filteredAssets.sort((a, b) => a.displayName.localeCompare(b.displayName));

    renderGallery();
  }

  function renderGallery() {
    assetCount.textContent = filteredAssets.length + " assets";
    gallery.innerHTML = "";
    gallery.className = `gallery ${viewMode}-view`;

    for (let i = 0; i < filteredAssets.length; i++) {
      const a = filteredAssets[i];
      const card = document.createElement("div");
      card.className = "asset-card";
      card.dataset.index = i;

      const catClass = a.category.startsWith("Marketing") ? "cat-Marketing" : `cat-${a.category}`;
      const extClass = `ext-${a.ext}`;

      card.innerHTML = `
        <span class="ext-badge ${extClass}">${a.ext}</span>
        <img class="thumb" src="/api/assets/${a.hash}" alt="${a.displayName}" loading="lazy" />
        <div class="card-info">
          <div class="card-name" title="${a.displayName}">${a.displayName}</div>
          <div class="card-variant" title="${a.variant}">${a.variant}</div>
          <span class="card-category ${catClass}">${a.category}</span>
        </div>
      `;

      card.addEventListener("click", () => openLightbox(i));
      gallery.appendChild(card);
    }
  }

  // ─── Lightbox ────────────────────────────────────────────────────────────

  function openLightbox(index) {
    if (index < 0 || index >= filteredAssets.length) return;
    lightboxIndex = index;
    const a = filteredAssets[index];

    lightboxImg.src = `/api/assets/${a.hash}`;
    lightboxName.textContent = `${a.displayName} [${a.variant}]`;
    lightboxPath.textContent = a.path;

    const sizeStr = a.size > 1048576 ? (a.size / 1048576).toFixed(1) + " MB" : (a.size / 1024).toFixed(0) + " KB";
    lightboxMeta.textContent = `${a.ext.toUpperCase()} \u00B7 ${sizeStr} \u00B7 ${index + 1} of ${filteredAssets.length}`;

    lightbox.classList.remove("hidden");
    document.body.style.overflow = "hidden";
  }

  function closeLightbox() {
    lightbox.classList.add("hidden");
    document.body.style.overflow = "";
    lightboxIndex = -1;
  }

  // ─── Event Listeners ────────────────────────────────────────────────────

  searchInput.addEventListener("input", applyFilters);
  filterCategory.addEventListener("change", applyFilters);
  filterType.addEventListener("change", applyFilters);
  sortBy.addEventListener("change", applyFilters);

  $("#btn-grid").addEventListener("click", () => {
    viewMode = "grid";
    $("#btn-grid").classList.add("active");
    $("#btn-list").classList.remove("active");
    renderGallery();
  });
  $("#btn-list").addEventListener("click", () => {
    viewMode = "list";
    $("#btn-list").classList.add("active");
    $("#btn-grid").classList.remove("active");
    renderGallery();
  });
  $("#btn-grid").classList.add("active");

  $("#btn-download-zip").addEventListener("click", () => {
    window.location.href = "/api/download-all";
  });

  $("#btn-new-file").addEventListener("click", () => {
    galleryScreen.classList.remove("active");
    uploadScreen.classList.add("active");
    progressContainer.classList.add("hidden");
    uploadError.classList.add("hidden");
    fileInput.value = "";
    assets = [];
    filteredAssets = [];
  });

  $("#lightbox-close").addEventListener("click", closeLightbox);
  $("#lightbox-prev").addEventListener("click", () => openLightbox(lightboxIndex - 1));
  $("#lightbox-next").addEventListener("click", () => openLightbox(lightboxIndex + 1));

  lightbox.addEventListener("click", (e) => {
    if (e.target === lightbox) closeLightbox();
  });

  $("#lightbox-download").addEventListener("click", () => {
    if (lightboxIndex >= 0 && lightboxIndex < filteredAssets.length) {
      const a = filteredAssets[lightboxIndex];
      window.location.href = `/api/download/${a.hash}`;
    }
  });

  document.addEventListener("keydown", (e) => {
    if (lightbox.classList.contains("hidden")) return;
    if (e.key === "Escape") closeLightbox();
    else if (e.key === "ArrowLeft") openLightbox(lightboxIndex - 1);
    else if (e.key === "ArrowRight") openLightbox(lightboxIndex + 1);
  });
})();

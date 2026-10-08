// The MxU Slides shell, mirroring apps/mac/Sources/AppShell.swift: a sidebar
// with the Service Flow and the Libraries, the present view in the middle,
// and the right rail with the Output Preview and the Service Controls.
(function () {
  const $ = (id) => document.getElementById(id);
  const api = {
    async get(path) {
      const response = await fetch(path, { cache: 'no-store' });
      if (!response.ok) throw new Error((await response.json().catch(() => ({}))).error || response.statusText);
      return response.json();
    },
    async post(path, body) {
      const response = await fetch(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) });
      if (!response.ok) throw new Error((await response.json().catch(() => ({}))).error || response.statusText);
      return response.json();
    },
  };

  const GLYPHS = {
    services: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="0.7" y="2.7" width="15.6" height="13.6" rx="3.5"/><line x1="5.5" y1="0.7" x2="5.5" y2="4.7" stroke-linecap="round"/><line x1="11.5" y1="0.7" x2="11.5" y2="4.7" stroke-linecap="round"/></svg>',
    presentations: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="4.2" y="4.2" width="12.1" height="12.1" rx="3"/><rect x="0.7" y="0.7" width="12.1" height="12.1" rx="3" fill="#262626"/></svg>',
    overlays: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="0.7" y="0.7" width="15.6" height="15.6" rx="3.5"/><rect x="3.5" y="11" width="10" height="3" rx="1" fill="currentColor" stroke="none"/></svg>',
    media: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><rect x="0.7" y="0.7" width="15.6" height="15.6" rx="3.5"/><path d="M3.5 13.5 L7.2 8.7 L9.6 11.6 L11.3 9.9 L13.5 13.5"/></svg>',
    audio: '<svg viewBox="0 0 17 17" fill="currentColor"><rect x="3" y="5" width="2" height="7" rx="1"/><rect x="7.5" y="2" width="2" height="13" rx="1"/><rect x="12" y="4" width="2" height="9" rx="1"/></svg>',
    themes: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><rect x="0.7" y="0.7" width="15.6" height="15.6" rx="3.5"/><line x1="4" y1="13" x2="13" y2="4"/></svg>',
    confidence: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="0.7" y="0.7" width="15.6" height="11" rx="2.5"/><line x1="4" y1="4" x2="11" y2="4" stroke-linecap="round"/><line x1="4" y1="7" x2="8.5" y2="7" stroke-linecap="round"/><line x1="8.5" y1="11.7" x2="8.5" y2="14"/><line x1="5" y1="15.5" x2="12" y2="15.5" stroke-linecap="round"/></svg>',
    playlists: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><line x1="1" y1="3.5" x2="12" y2="3.5"/><line x1="1" y1="8.5" x2="12" y2="8.5"/><line x1="1" y1="13.5" x2="8" y2="13.5"/><path d="M12.5 10.5 L16 12.5 L12.5 14.5 Z" fill="currentColor"/></svg>',
    header: '<svg viewBox="0 0 17 17" fill="currentColor"><rect x="1" y="7.5" width="15" height="2" rx="1"/></svg>',
    info: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="8.5" cy="8.5" r="7.3"/><line x1="8.5" y1="7.5" x2="8.5" y2="12.5" stroke-linecap="round"/><circle cx="8.5" cy="5" r="0.5" fill="currentColor"/></svg>',
    timers: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><line x1="6.5" y1="1" x2="10.5" y2="1"/><line x1="8.5" y1="1" x2="8.5" y2="3.4"/><circle cx="8.5" cy="10.2" r="6.1"/><line x1="8.5" y1="10.2" x2="11.9" y2="6.8"/></svg>',
    alerts: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12.6 C4 10.5 4.8 1.4 8.5 1.4 C12.2 1.4 13 10.5 15 12.6 Z"/><path d="M6.8 14.3 Q8.5 16.5 10.2 14.3"/></svg>',
    combos: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"><path d="M10.2 0.5 L2.7 9.9 L7.5 9.9 L6.8 16.7 L14.3 7.1 L9.5 7.1 Z"/></svg>',
    outputs: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="0.7" y="0.7" width="15.6" height="11" rx="2.5"/><line x1="8.5" y1="11.7" x2="8.5" y2="14"/><line x1="5" y1="15.5" x2="12" y2="15.5" stroke-linecap="round"/></svg>',
    mixer: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><line x1="3" y1="1" x2="3" y2="5"/><circle cx="3" cy="7.5" r="2.2"/><line x1="3" y1="10" x2="3" y2="16"/><line x1="8.5" y1="1" x2="8.5" y2="9"/><circle cx="8.5" cy="11.5" r="2.2"/><line x1="8.5" y1="14" x2="8.5" y2="16"/><line x1="14" y1="1" x2="14" y2="3"/><circle cx="14" cy="5.5" r="2.2"/><line x1="14" y1="8" x2="14" y2="16"/></svg>',
    tracking: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><circle cx="8.5" cy="8.5" r="7.3"/><path d="M8.5 4 L8.5 8.5 L11.5 10.5"/></svg>',
  };

  const LIBRARY_TABS = [
    ['services', 'Services'], ['presentations', 'Presentations'], ['overlays', 'Overlays'],
    ['media', 'Media'], ['audio', 'Audio'], ['themes', 'Themes'], ['confidence', 'Confidence'],
  ];
  const MODULES = [
    ['audio', 'Audio'], ['mixer', 'Mixer'], ['media', 'Media'], ['timers', 'Timers'], ['tracking', 'Tracking'],
    ['alerts', 'Alerts'], ['overlays', 'Overlays'], ['combos', 'Combos'], ['confidence', 'Confidence'], ['outputs', 'Outputs'],
  ];

  const prefs = {
    get(key, fallback) { try { const v = localStorage.getItem(key); return v == null ? fallback : JSON.parse(v); } catch { return fallback; } },
    set(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch {} },
  };

  const ui = {
    state: null,
    version: null,
    librarySection: prefs.get('library.section', 'presentations'),
    selectedEntry: null,
    selectedItem: null,
    module: prefs.get('serviceControls.module', 'overlays'),
    slidesAcross: prefs.get('slidesAcross', 5),
    mode: 'present',
    presentations: new Map(),   // id -> { listing, sequence }
    scenes: new Map(),          // key -> scene
    renderers: new Map(),       // tile key -> renderer
    previewRenderer: null,
    previewVersion: null,
    search: '',
  };

  function librarySequence() { return ui.state ? Math.floor(ui.state.version / 1000) : 0; }

  // ---------- Service Flow ----------

  function renderServiceHeader() {
    const service = ui.state.service;
    $('service-name').textContent = service ? service.name : 'Choose…';
    $('service-date').textContent = service && service.date ? formatDate(service.date) : '';
  }

  function formatDate(iso) {
    const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso || '');
    if (!match) return iso || '';
    const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
    return date.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' });
  }

  function renderRunOrder() {
    const list = $('run-order');
    const service = ui.state.service;
    list.innerHTML = '';
    if (!service) {
      list.innerHTML = '<div class="empty"><strong>No Service</strong>Create one from the menu above.</div>';
      return;
    }
    const live = ui.state.live;
    for (const item of service.items) {
      const row = document.createElement('div');
      row.className = 'run-row ' + (item.kind === 'header' ? 'header' : '');
      if (item.hidden) row.classList.add('hidden-item');
      if (live && live.contextId === item.id) row.classList.add('live');
      if (ui.selectedItem === item.id) row.classList.add('selected');
      if (item.kind === 'header') {
        row.innerHTML = `<span class="swatch" style="background:${hex(item.colorHex) || 'var(--quaternary)'}"></span><span class="name">${escape(item.name)}</span>`;
      } else {
        const glyph = { presentation: 'presentations', media: 'media', audio: 'audio', playlist: 'playlists', info: 'info' }[item.kind] || 'presentations';
        row.innerHTML = `<span class="row-glyph">${GLYPHS[glyph]}</span><span class="name">${escape(item.name)}</span>`;
        if (item.kind === 'presentation') {
          const listing = ui.presentations.get(item.refId);
          if (listing) row.insertAdjacentHTML('beforeend', `<span class="count">${listing.listing.slides.length}</span>`);
        }
      }
      row.addEventListener('click', () => {
        ui.selectedItem = item.id;
        ui.selectedEntry = null;
        renderRunOrder();
        const deck = document.querySelector(`.deck[data-item="${cssEscape(item.id)}"]`) || document.querySelector(`.service-band[data-item="${cssEscape(item.id)}"]`);
        if (deck) deck.scrollIntoView({ block: 'start', behavior: 'smooth' });
      });
      list.appendChild(row);
    }
  }

  // ---------- Libraries ----------

  function renderLibraryTabs() {
    const row = $('library-tabs');
    row.innerHTML = '';
    for (const [id, title] of LIBRARY_TABS) {
      const tab = document.createElement('button');
      tab.className = 'tab' + (ui.librarySection === id ? ' selected' : '');
      tab.innerHTML = `${GLYPHS[id]}<span>${title}</span>`;
      tab.title = title;
      tab.addEventListener('click', () => { ui.librarySection = id; prefs.set('library.section', id); renderLibraryTabs(); renderLibraryList(); });
      row.appendChild(tab);
    }
  }

  function renderLibraryList() {
    const list = $('library-list');
    const section = ui.librarySection;
    let entries = (ui.state.sections[section] || []).slice();
    if (section === 'services') entries = ui.state.services.slice().sort((a, b) => (b.date || '').localeCompare(a.date || '') || a.name.localeCompare(b.name));
    const query = ui.search.trim().toLowerCase();
    if (query) entries = entries.filter(e => e.name.toLowerCase().includes(query));
    list.innerHTML = '';
    $('library-count').textContent = entries.length ? `${entries.length} ${LIBRARY_TABS.find(t => t[0] === section)[1].toLowerCase()}` : '';
    if (!entries.length) {
      const name = LIBRARY_TABS.find(t => t[0] === section)[1];
      list.innerHTML = `<div class="empty"><strong>No ${name}</strong>${query ? 'Nothing matches the search.' : (section === 'media' || section === 'audio' ? 'Import comes to Windows later.' : 'Use New to create one.')}</div>`;
      return;
    }
    for (const entry of entries) {
      const row = document.createElement('div');
      row.className = 'list-row' + (ui.selectedEntry === entry.id ? ' selected' : '');
      const trailing = section === 'services' ? `<span class="folder">${escape(entry.date ? entry.date : '')}</span>` : (entry.folder ? `<span class="folder">${escape(entry.folder)}</span>` : '');
      row.innerHTML = `<span class="name">${escape(entry.name)}</span>${trailing}`;
      row.addEventListener('click', () => selectEntry(section, entry));
      row.addEventListener('dblclick', () => { if (section === 'services') chooseService(entry.id); });
      list.appendChild(row);
    }
  }

  function selectEntry(section, entry) {
    if (section === 'services') { chooseService(entry.id); return; }
    ui.selectedEntry = entry.id;
    ui.selectedItem = null;
    renderLibraryList();
    renderRunOrder();
    renderPresentView();
  }

  async function chooseService(id) {
    try { await api.post('/ui/v1/service', { id }); ui.selectedItem = null; ui.selectedEntry = null; await refresh(true); }
    catch (error) { toast(error.message); }
  }

  // ---------- Present view ----------

  async function loadPresentation(id, arrangementId) {
    const key = `${id}|${arrangementId || ''}`;
    const cached = ui.presentations.get(key);
    if (cached && cached.sequence === librarySequence()) return cached.listing;
    const listing = await api.get(`/ui/v1/presentations/${encodeURIComponent(id)}${arrangementId ? `?arrangement=${encodeURIComponent(arrangementId)}` : ''}`);
    ui.presentations.set(key, { listing, sequence: librarySequence() });
    ui.presentations.set(id, { listing, sequence: librarySequence() });
    return listing;
  }

  let presentRenderToken = 0;

  async function renderPresentView() {
    const view = $('present-view');
    const token = ++presentRenderToken;
    const state = ui.state;
    if (ui.mode !== 'present') {
      view.innerHTML = `<div class="unavailable-view"><div><strong>${ui.mode === 'edit' ? 'Edit' : 'Scheduler'} is coming to Windows</strong>The editor, themes and the scheduler are not on Windows yet. Present mode runs your services.</div></div>`;
      return;
    }
    const fragment = document.createDocumentFragment();
    const selected = ui.selectedEntry && (state.sections.presentations || []).find(e => e.id === ui.selectedEntry);
    if (selected) {
      const listing = await loadPresentation(selected.id, null);
      if (token !== presentRenderToken) return;
      fragment.appendChild(deckElement(listing, { contextId: selected.id, itemId: null, arrangementId: null }));
    } else if (state.service) {
      for (const item of state.service.items) {
        if (item.hidden) continue;
        if (item.kind === 'header') {
          const band = document.createElement('div');
          band.className = 'service-band';
          band.dataset.item = item.id;
          band.innerHTML = `<span class="swatch" style="background:${hex(item.colorHex) || 'var(--quaternary)'}"></span><span>${escape(item.name)}</span>`;
          fragment.appendChild(band);
        } else if (item.kind === 'presentation') {
          let listing;
          try { listing = await loadPresentation(item.refId, item.arrangementId); }
          catch { listing = null; }
          if (token !== presentRenderToken) return;
          if (listing) fragment.appendChild(deckElement(listing, { contextId: item.id, itemId: item.id, arrangementId: item.arrangementId }));
          else fragment.appendChild(mediaCard(item, 'Presentation not found'));
        } else {
          fragment.appendChild(mediaCard(item, item.kind === 'media' ? 'Video and image playback are not on Windows yet' : item.kind === 'audio' ? 'Audio playback is not on Windows yet' : ''));
        }
      }
    } else {
      fragment.innerHTML = '';
      const empty = document.createElement('div');
      empty.className = 'unavailable-view';
      empty.innerHTML = '<div><strong>No Service</strong>Choose a service to present.</div>';
      fragment.appendChild(empty);
    }
    view.innerHTML = '';
    view.appendChild(fragment);
    ui.renderers.clear();
    observeTiles();
    updateLiveHighlight();
  }

  function mediaCard(item, note) {
    const card = document.createElement('div');
    card.className = 'media-card';
    card.dataset.item = item.id;
    const glyph = { media: 'media', audio: 'audio', playlist: 'playlists', info: 'info' }[item.kind] || 'info';
    card.innerHTML = `<span class="row-glyph">${GLYPHS[glyph]}</span><span class="name">${escape(item.name)}</span><span class="muted">${escape(note)}</span>`;
    return card;
  }

  function deckElement(listing, context) {
    const deck = document.createElement('section');
    deck.className = 'deck';
    deck.dataset.presentation = listing.id;
    deck.dataset.context = context.contextId;
    if (context.itemId) deck.dataset.item = context.itemId;
    const arrangement = listing.arrangements.find(a => a.id === listing.arrangementId);
    deck.innerHTML = `<div class="deck-header"><span class="deck-title">${escape(listing.name)}</span>${arrangement ? `<span class="deck-chip">${escape(arrangement.name)}</span>` : ''}${listing.musicKey ? `<span class="deck-chip">Key ${escape(listing.musicKey)}</span>` : ''}<span class="deck-chip muted">${listing.slides.length} slides</span></div>`;
    const grid = document.createElement('div');
    grid.className = 'slide-grid';
    grid.style.gridTemplateColumns = `repeat(${ui.slidesAcross}, minmax(0, 1fr))`;
    for (const slide of listing.slides) {
      const tile = document.createElement('div');
      tile.className = 'tile';
      tile.dataset.index = slide.index;
      tile.dataset.presentation = listing.id;
      tile.dataset.context = context.contextId;
      tile.dataset.arrangement = listing.arrangementId || '';
      const frame = document.createElement('div');
      frame.className = 'tile-frame';
      const canvas = document.createElement('canvas');
      frame.appendChild(canvas);
      tile.appendChild(frame);
      const label = document.createElement('div');
      label.className = 'tile-label';
      label.innerHTML = `${slide.sectionColorHex || slide.sectionName ? `<span class="section-bar" style="background:${hex(slide.sectionColorHex) || 'var(--quaternary)'}"></span>` : ''}<span class="num">${slide.index + 1}</span><span class="text" title="${escape(slide.label)}">${escape(slide.label)}</span>`;
      tile.appendChild(label);
      tile.addEventListener('click', () => fire(listing.id, slide.index, context.contextId, listing.arrangementId));
      grid.appendChild(tile);
    }
    deck.appendChild(grid);
    return deck;
  }

  const tileObserver = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (entry.isIntersecting) drawTile(entry.target);
    }
  }, { root: $('present-view'), rootMargin: '400px 0px' });

  function observeTiles() {
    for (const tile of document.querySelectorAll('.tile')) tileObserver.observe(tile);
  }

  async function drawTile(tile) {
    const key = `${tile.dataset.presentation}|${tile.dataset.arrangement}|${tile.dataset.index}`;
    if (tile.dataset.drawn === String(librarySequence())) return;
    tile.dataset.drawn = String(librarySequence());
    const scene = await sceneFor(tile.dataset.presentation, tile.dataset.index, tile.dataset.arrangement);
    if (!scene || !tile.isConnected) return;
    const canvas = tile.querySelector('canvas');
    const dpr = window.devicePixelRatio || 1;
    const width = Math.max(canvas.clientWidth, 120) * dpr;
    canvas.width = Math.round(width);
    canvas.height = Math.round(width * scene.height / scene.width);
    let renderer = ui.renderers.get(key);
    if (!renderer) { renderer = new SceneRenderer(canvas); ui.renderers.set(key, renderer); }
    renderer.draw(scene);
  }

  async function sceneFor(presentationId, index, arrangementId) {
    const key = `${presentationId}|${arrangementId || ''}|${index}|${librarySequence()}`;
    if (ui.scenes.has(key)) return ui.scenes.get(key);
    try {
      const scene = await api.get(`/ui/v1/scene/slide/${encodeURIComponent(presentationId)}/${index}${arrangementId ? `?arrangement=${encodeURIComponent(arrangementId)}` : ''}`);
      ui.scenes.set(key, scene);
      if (ui.scenes.size > 600) ui.scenes.delete(ui.scenes.keys().next().value);
      return scene;
    } catch (error) {
      return null;
    }
  }

  function updateLiveHighlight() {
    const live = ui.state && ui.state.live;
    for (const tile of document.querySelectorAll('.tile')) {
      const isLive = !!live && tile.dataset.context === live.contextId && Number(tile.dataset.index) === live.occurrence;
      tile.classList.toggle('live', isLive);
      const badge = tile.querySelector('.tile-badge');
      if (isLive && !badge) tile.querySelector('.tile-frame').insertAdjacentHTML('beforeend', '<span class="tile-badge">LIVE</span>');
      if (!isLive && badge) badge.remove();
    }
  }

  function revealLive() {
    const live = ui.state && ui.state.live;
    if (!live) return;
    const tile = [...document.querySelectorAll('.tile')].find(t => t.dataset.context === live.contextId && Number(t.dataset.index) === live.occurrence);
    if (tile) tile.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  }

  async function fire(presentationId, index, contextId, arrangementId) {
    try { await api.post('/ui/v1/fire', { presentationId, index, contextId, arrangementId: arrangementId || null }); await refresh(); }
    catch (error) { toast(error.message); }
  }

  async function advance(steps, settled) {
    try { await api.post('/ui/v1/advance', { steps, settled: !!settled }); await refresh(); revealLive(); }
    catch (error) { toast(error.message); }
  }

  async function clear(body) {
    try { await api.post('/ui/v1/clear', body); await refresh(); }
    catch (error) { toast(error.message); }
  }

  // ---------- Preview and confidence ----------

  async function renderPreview(force) {
    if (!ui.previewRenderer) {
      ui.previewRenderer = new SceneRenderer($('preview-canvas'), { onMediaLoaded: () => {} });
    }
    if (!force && ui.previewVersion === ui.state.version) return;
    ui.previewVersion = ui.state.version;
    try {
      const scene = await api.get('/ui/v1/scene/live');
      const canvas = $('preview-canvas');
      const dpr = window.devicePixelRatio || 1;
      canvas.width = Math.round(Math.max(canvas.clientWidth, 200) * dpr);
      canvas.height = Math.round(canvas.width * 9 / 16);
      ui.previewRenderer.draw(scene);
    } catch (error) { /* keep the last frame */ }
    const live = ui.state.live;
    $('preview-badge').hidden = !live && !Object.keys(ui.state.mediaLayers).length && !ui.state.overlays.length;
    $('current-text').textContent = live ? (live.text || live.slideName || `${live.presentationName || ''} ${live.occurrence + 1}`) : '—';
    $('next-text').textContent = ui.state.nextText || (live ? 'End of service' : '—');
    const clearChip = $('clear-all');
    clearChip.classList.toggle('armed', !!live || Object.keys(ui.state.mediaLayers).length > 0 || ui.state.overlays.length > 0 || !!ui.state.alert);
  }

  // ---------- Service Controls modules ----------

  function renderModuleTabs() {
    const row = $('module-tabs');
    row.innerHTML = '';
    for (const [id, title] of MODULES) {
      const tab = document.createElement('button');
      tab.className = 'tab' + (ui.module === id ? ' selected' : '');
      tab.innerHTML = `${GLYPHS[id] || ''}<span>${title}</span>`;
      const activity = moduleActivity(id);
      if (activity) tab.insertAdjacentHTML('beforeend', `<span class="activity" style="background:${activity}"></span>`);
      tab.addEventListener('click', () => { ui.module = id; prefs.set('serviceControls.module', id); renderModuleTabs(); renderModule(); });
      row.appendChild(tab);
    }
  }

  function moduleActivity(id) {
    if (!ui.state) return null;
    if (id === 'overlays' && ui.state.overlays.length) return 'var(--green)';
    if (id === 'alerts' && ui.state.alert) return 'var(--orange)';
    return null;
  }

  function renderModule() {
    const body = $('module-body');
    body.innerHTML = '';
    const state = ui.state;
    switch (ui.module) {
      case 'overlays': {
        const overlays = state.sections.overlays || [];
        if (!overlays.length) { body.innerHTML = '<div class="module-note">No overlays in the library.</div>'; break; }
        const byFolder = new Map();
        for (const overlay of overlays) {
          const folder = overlay.folder || '';
          if (!byFolder.has(folder)) byFolder.set(folder, []);
          byFolder.get(folder).push(overlay);
        }
        for (const [folder, list] of byFolder) {
          if (folder) body.insertAdjacentHTML('beforeend', `<div class="module-heading">${escape(folder)}</div>`);
          for (const overlay of list) {
            const live = state.overlays.some(o => o.id === overlay.id);
            const row = document.createElement('div');
            row.className = 'module-row' + (live ? ' live' : '');
            row.innerHTML = `<span class="name">${escape(overlay.name)}</span>`;
            const button = document.createElement('button');
            button.className = 'card-button' + (live ? ' destructive' : '');
            button.textContent = live ? 'Dismiss' : 'Fire';
            button.addEventListener('click', async () => {
              try { await api.post('/ui/v1/overlay', { id: overlay.id, action: live ? 'dismiss' : 'fire' }); await refresh(); }
              catch (error) { toast(error.message); }
            });
            row.appendChild(button);
            body.appendChild(row);
          }
        }
        break;
      }
      case 'alerts': {
        const live = state.alert;
        body.insertAdjacentHTML('beforeend', `<div class="module-heading">Ad-hoc alert</div>`);
        const field = document.createElement('textarea');
        field.className = 'field';
        field.rows = 3;
        field.placeholder = 'Message for the audience screen';
        field.value = live ? live.message : '';
        body.appendChild(field);
        const row = document.createElement('div');
        row.className = 'module-row';
        const target = document.createElement('select');
        target.className = 'field';
        target.innerHTML = '<option value="audience">Audience</option><option value="both">Audience + Confidence</option><option value="confidence">Confidence only</option>';
        row.appendChild(target);
        body.appendChild(row);
        const buttons = document.createElement('div');
        buttons.className = 'module-row';
        const fireButton = document.createElement('button');
        fireButton.className = 'card-button primary';
        fireButton.textContent = 'Fire Alert';
        fireButton.addEventListener('click', async () => {
          try { await api.post('/ui/v1/alert', { message: field.value, target: target.value, behavior: 'persist' }); await refresh(); }
          catch (error) { toast(error.message); }
        });
        const dismiss = document.createElement('button');
        dismiss.className = 'card-button destructive';
        dismiss.textContent = 'Dismiss';
        dismiss.disabled = !live;
        dismiss.addEventListener('click', async () => { try { await api.post('/ui/v1/alert', { dismiss: true }); await refresh(); } catch (error) { toast(error.message); } });
        buttons.append(fireButton, dismiss);
        body.appendChild(buttons);
        if (live) body.insertAdjacentHTML('beforeend', `<div class="module-note">Live: “${escape(live.message)}” (${escape(live.target)})</div>`);
        break;
      }
      case 'outputs': {
        body.insertAdjacentHTML('beforeend', '<div class="module-heading">Screens</div><div class="module-note">Open the output in its own window and drag it to the projector or second display. Double-click it for full screen.</div>');
        const row = document.createElement('div');
        row.className = 'module-row';
        const open = document.createElement('button');
        open.className = 'card-button primary';
        open.textContent = 'Open Output Window';
        open.addEventListener('click', () => window.open('/output', 'mxu-output', 'popup=yes,width=960,height=540'));
        row.appendChild(open);
        body.appendChild(row);
        body.insertAdjacentHTML('beforeend', `<div class="module-note">Screen roles, NDI, DeckLink and output presets are not on Windows yet.</div>`);
        if (state.localAPIPort) body.insertAdjacentHTML('beforeend', `<div class="module-heading">Local API</div><div class="module-note">Remotes connect on port ${state.localAPIPort}. The default key is printed in the console that started the app.</div>`);
        break;
      }
      case 'confidence':
        body.innerHTML = `<div class="module-heading">Current</div><div class="readout-text">${escape(state.live ? state.live.text || '' : '—')}</div><div class="module-heading">Next</div><div class="readout-text next">${escape(state.nextText || '—')}</div><div class="module-note">Confidence layouts and the stage display are not on Windows yet; this readout shows what they would.</div>`;
        break;
      default:
        body.innerHTML = `<div class="module-note">${escape(MODULES.find(m => m[0] === ui.module)[1])} is not on Windows yet. It needs the audio, media and timer engines, which are still Mac-only.</div>`;
    }
  }

  // ---------- Header menus ----------

  function popover(anchor, build) {
    const pop = $('popover');
    pop.innerHTML = '';
    build(pop);
    pop.hidden = false;
    const rect = anchor.getBoundingClientRect();
    pop.style.left = `${Math.min(rect.left, window.innerWidth - pop.offsetWidth - 8)}px`;
    pop.style.top = `${rect.bottom + 6}px`;
    const close = (event) => { if (!pop.contains(event.target) && event.target !== anchor) { pop.hidden = true; document.removeEventListener('mousedown', close, true); } };
    setTimeout(() => document.addEventListener('mousedown', close, true), 0);
  }

  function closePopover() { $('popover').hidden = true; }

  function menuRow(pop, label, { current, action, date, destructive, section } = {}) {
    const row = document.createElement('div');
    row.className = 'menu-row' + (current ? ' current' : '') + (destructive ? ' destructive' : '');
    row.innerHTML = `<span>${escape(label)}</span>${date ? `<span class="date">${escape(date)}</span>` : ''}`;
    if (action) row.addEventListener('click', () => { closePopover(); action(); });
    pop.appendChild(row);
    return row;
  }

  function wireHeader() {
    $('service-menu').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      const today = new Date().toISOString().slice(0, 10);
      const services = ui.state.services.slice();
      const current = services.filter(s => !s.date || s.date >= today).sort((a, b) => (a.date || '9').localeCompare(b.date || '9') || a.name.localeCompare(b.name));
      const earlier = services.filter(s => s.date && s.date < today).sort((a, b) => b.date.localeCompare(a.date));
      if (!services.length) menuRow(pop, 'No services yet');
      for (const service of current) menuRow(pop, service.name, { current: ui.state.service && ui.state.service.id === service.id, date: service.date ? service.date.slice(5) : '', action: () => chooseService(service.id) });
      if (earlier.length) {
        pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div><div class="menu-section">Earlier</div>');
        for (const service of earlier.slice(0, 12)) menuRow(pop, service.name, { current: ui.state.service && ui.state.service.id === service.id, date: service.date.slice(0, 10), action: () => chooseService(service.id) });
      }
    }));

    $('mode-switcher').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      for (const [mode, title] of [['present', 'Present'], ['edit', 'Edit'], ['scheduler', 'Scheduler']]) {
        menuRow(pop, title, { current: ui.mode === mode, action: () => setMode(mode) });
      }
    }));

    $('clear-all').addEventListener('click', () => clear({ all: true }));
    $('clear-menu-button').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      pop.insertAdjacentHTML('beforeend', '<div class="menu-section">Clear</div>');
      for (const [fn, title] of [['slides', 'Slides'], ['media', 'Media'], ['overlays', 'Overlays'], ['alerts', 'Alerts'], ['audio', 'Music']]) {
        menuRow(pop, title, { action: () => clear({ function: fn }) });
      }
      pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div>');
      menuRow(pop, 'Clear All', { destructive: true, action: () => clear({ all: true }) });
    }));

    $('view-options').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      const row = document.createElement('label');
      row.className = 'menu-row';
      row.innerHTML = `<span>Slides Across</span><input type="range" min="2" max="10" step="1" value="${ui.slidesAcross}"><span class="date">${ui.slidesAcross}</span>`;
      const input = row.querySelector('input');
      input.addEventListener('input', () => {
        ui.slidesAcross = Number(input.value);
        prefs.set('slidesAcross', ui.slidesAcross);
        row.querySelector('.date').textContent = input.value;
        for (const grid of document.querySelectorAll('.slide-grid')) grid.style.gridTemplateColumns = `repeat(${ui.slidesAcross}, minmax(0, 1fr))`;
        for (const tile of document.querySelectorAll('.tile')) { tile.dataset.drawn = ''; }
        observeTiles();
      });
      pop.appendChild(row);
      pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div>');
      menuRow(pop, 'Hide Right Panels', { action: () => $('shell').classList.toggle('rail-hidden') });
    }));

    $('sidebar-toggle').addEventListener('click', () => $('sidebar').classList.toggle('hidden'));
    $('library-search').addEventListener('input', (event) => { ui.search = event.target.value; renderLibraryList(); });

    $('present-view').addEventListener('mousedown', () => $('present-view').focus());
    document.addEventListener('keydown', (event) => {
      const typing = ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement && document.activeElement.tagName);
      if (typing) return;
      if (event.key === 'ArrowRight' || event.key === ' ' || event.key === 'Enter') { event.preventDefault(); advance(1, event.altKey); }
      else if (event.key === 'ArrowLeft') { event.preventDefault(); advance(-1); }
      else if (event.key === 'Escape') { closePopover(); }
      else if ((event.ctrlKey || event.metaKey) && event.key === 'f') { event.preventDefault(); $('library-search').focus(); }
    });

    const grip = $('sidebar-grip');
    let dragging = null;
    grip.addEventListener('mousedown', (event) => { dragging = { startY: event.clientY, start: $('service-panel').getBoundingClientRect().height }; event.preventDefault(); });
    window.addEventListener('mousemove', (event) => {
      if (!dragging) return;
      const total = $('sidebar').getBoundingClientRect().height;
      const next = Math.min(Math.max(dragging.start + event.clientY - dragging.startY, 170), total - 180);
      $('service-panel').style.flex = `0 0 ${next}px`;
    });
    window.addEventListener('mouseup', () => { dragging = null; });
  }

  function setMode(mode) {
    ui.mode = mode;
    $('mode-title').textContent = { present: 'Present', edit: 'Edit', scheduler: 'Scheduler' }[mode];
    $('edit-contexts').hidden = mode !== 'edit';
    renderPresentView();
  }

  // ---------- Polling ----------

  let polling = false;
  async function refresh(force) {
    if (polling && !force) return;
    polling = true;
    try {
      const state = await api.get('/ui/v1/state');
      const first = !ui.state;
      const changed = force || !ui.state || state.version !== ui.state.version;
      const libraryChanged = !ui.state || Math.floor(state.version / 1000) !== Math.floor(ui.state.version / 1000);
      const serviceChanged = !ui.state || JSON.stringify(state.service) !== JSON.stringify(ui.state.service);
      ui.state = state;
      if (first) { renderLibraryTabs(); renderModuleTabs(); }
      if (changed) {
        renderServiceHeader();
        if (libraryChanged) { ui.scenes.clear(); renderLibraryList(); }
        if (serviceChanged || libraryChanged) await renderPresentView(); else { updateLiveHighlight(); }
        renderRunOrder();
        renderModuleTabs();
        renderModule();
        await renderPreview(libraryChanged);
      }
    } catch (error) {
      if (!ui.state) $('present-view').innerHTML = `<div class="unavailable-view"><div><strong>Waiting for the host</strong>${escape(error.message)}</div></div>`;
    } finally {
      polling = false;
    }
  }

  function toast(message) {
    const el = $('toast');
    el.textContent = message;
    el.hidden = false;
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => { el.hidden = true; }, 2400);
  }

  function escape(value) { return String(value == null ? '' : value).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
  function cssEscape(value) { return (window.CSS && CSS.escape) ? CSS.escape(value) : String(value).replace(/["\\]/g, '\\$&'); }
  function hex(value) {
    if (!value) return null;
    const m = /^#?([0-9a-f]{6})([0-9a-f]{2})?$/i.exec(value);
    if (!m) return null;
    return m[2] ? `#${m[1]}${m[2]}` : `#${m[1]}`;
  }

  wireHeader();
  setMode('present');
  refresh(true);
  setInterval(() => refresh(), 300);
  window.addEventListener('resize', () => { ui.previewVersion = null; for (const tile of document.querySelectorAll('.tile')) tile.dataset.drawn = ''; observeTiles(); });
})();

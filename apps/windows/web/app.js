// The MxU Slides shell, mirroring apps/mac/Sources/AppShell.swift and the views
// it composes (ServicePlannerView's run order, LibraryView's sidebar,
// ServiceContinuousView's deck cards, LivePanel, ServiceControlsPanel with its
// PriorityTabRow, MediaTransportStrip), laid out against a screenshot of the
// Mac app.
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

  // Glyphs after apps/mac/Sources/Glyphs.swift (GlyphKind), drawn at 17pt.
  const G = {
    sidebar: '<svg width="17" height="13.5" viewBox="0 0 17 13.5" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="0.7" y="0.7" width="15.6" height="12.1" rx="3.3"/><line x1="6.3" y1="1.4" x2="6.3" y2="12.1"/></svg>',
    viewOptions: '<svg width="17" height="13.5" viewBox="0 0 17 13.5" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><line x1="0.7" y1="2.2" x2="9.6" y2="2.2"/><circle cx="12" cy="2.2" r="2.2"/><line x1="14.3" y1="2.2" x2="16.3" y2="2.2"/><line x1="0.7" y1="6.75" x2="2.2" y2="6.75"/><circle cx="4.6" cy="6.75" r="2.2"/><line x1="6.9" y1="6.75" x2="16.3" y2="6.75"/><line x1="0.7" y1="11.3" x2="7" y2="11.3"/><circle cx="9.4" cy="11.3" r="2.2"/><line x1="11.7" y1="11.3" x2="16.3" y2="11.3"/></svg>',
    presentations: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="4.2" y="4.2" width="12.1" height="12.1" rx="3"/><rect x="0.7" y="0.7" width="12.1" height="12.1" rx="3" fill="var(--glyph-fill, #262626)"/></svg>',
    overlays: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="0.7" y="0.7" width="15.6" height="15.6" rx="3.5"/><rect x="3.5" y="11" width="10" height="3" rx="1" fill="currentColor" stroke="none"/></svg>',
    media: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><rect x="0.7" y="0.7" width="15.6" height="15.6" rx="3.5"/><path d="M3.5 13.5 L7.2 8.7 L9.6 11.6 L11.3 9.9 L13.5 13.5"/><circle cx="11.8" cy="5.2" r="1.3"/></svg>',
    audio: '<svg viewBox="0 0 17 17" fill="currentColor"><rect x="1.5" y="6" width="2" height="5" rx="1"/><rect x="5" y="3" width="2" height="11" rx="1"/><rect x="8.5" y="1" width="2" height="15" rx="1"/><rect x="12" y="4.5" width="2" height="8" rx="1"/><rect x="15.2" y="6.5" width="1.3" height="4" rx="0.65"/></svg>',
    themes: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><path d="M8.5 1.2 C4.4 1.2 1.2 4.4 1.2 8.5 C1.2 12.6 4.4 15.8 8.5 15.8 C9.6 15.8 10.3 15 10 14 C9.7 13 10.3 12 11.4 12 L13 12 C14.6 12 15.8 10.8 15.8 9.2 C15.8 4.8 12.5 1.2 8.5 1.2 Z"/><circle cx="5" cy="8" r="1" fill="currentColor"/><circle cx="7.5" cy="4.8" r="1" fill="currentColor"/><circle cx="11.5" cy="5.5" r="1" fill="currentColor"/></svg>',
    confidence: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><rect x="0.7" y="0.7" width="15.6" height="9.6" rx="2.5"/><line x1="3" y1="13.2" x2="14" y2="13.2"/><line x1="3" y1="16" x2="10" y2="16"/></svg>',
    folder: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"><path d="M1 4 Q1 2.8 2.2 2.8 H6 L7.8 4.6 H14.8 Q16 4.6 16 5.8 V13 Q16 14.2 14.8 14.2 H2.2 Q1 14.2 1 13 Z"/></svg>',
    broadcast: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="8.5" cy="8.5" r="7.3"/><circle cx="8.5" cy="8.5" r="2.6" fill="currentColor" stroke="none"/></svg>',
    screens: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><rect x="0.7" y="1.7" width="15.6" height="10.6" rx="2.2"/><line x1="8.5" y1="12.3" x2="8.5" y2="15"/><line x1="5" y1="15.5" x2="12" y2="15.5"/></svg>',
    clear: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><circle cx="8.5" cy="8.5" r="6.8"/><line x1="4" y1="13" x2="13" y2="4"/></svg>',
    ellipsis: '<svg viewBox="0 0 17 17" fill="currentColor"><circle cx="3.2" cy="8.5" r="1.6"/><circle cx="8.5" cy="8.5" r="1.6"/><circle cx="13.8" cy="8.5" r="1.6"/></svg>',
    popout: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><rect x="1.2" y="1.2" width="14.6" height="14.6" rx="3"/><path d="M6.5 10.5 L11 6 M7.5 6 H11 V9.5"/></svg>',
    filter: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><line x1="1.5" y1="4" x2="15.5" y2="4"/><line x1="4" y1="8.5" x2="13" y2="8.5"/><line x1="6.5" y1="13" x2="10.5" y2="13"/></svg>',
    list: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"><circle cx="2.5" cy="4" r="1" fill="currentColor" stroke="none"/><circle cx="2.5" cy="8.5" r="1" fill="currentColor" stroke="none"/><circle cx="2.5" cy="13" r="1" fill="currentColor" stroke="none"/><line x1="6" y1="4" x2="15.5" y2="4"/><line x1="6" y1="8.5" x2="15.5" y2="8.5"/><line x1="6" y1="13" x2="15.5" y2="13"/></svg>',
    timers: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><line x1="6.5" y1="1" x2="10.5" y2="1"/><line x1="8.5" y1="1" x2="8.5" y2="3.4"/><circle cx="8.5" cy="10.2" r="6.1"/><line x1="8.5" y1="10.2" x2="11.9" y2="6.8"/></svg>',
    alerts: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12.6 C4 10.5 4.8 1.4 8.5 1.4 C12.2 1.4 13 10.5 15 12.6 Z"/><path d="M6.8 14.3 Q8.5 16.5 10.2 14.3"/></svg>',
    combos: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"><path d="M10.2 0.5 L2.7 9.9 L7.5 9.9 L6.8 16.7 L14.3 7.1 L9.5 7.1 Z"/></svg>',
    outputs: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><rect x="0.7" y="1.7" width="15.6" height="10.6" rx="2.2"/><line x1="8.5" y1="12.3" x2="8.5" y2="15"/><line x1="5" y1="15.5" x2="12" y2="15.5"/></svg>',
    mixer: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><line x1="3" y1="1" x2="3" y2="5"/><circle cx="3" cy="7.5" r="2.2"/><line x1="3" y1="10" x2="3" y2="16"/><line x1="8.5" y1="1" x2="8.5" y2="9"/><circle cx="8.5" cy="11.5" r="2.2"/><line x1="8.5" y1="14" x2="8.5" y2="16"/><line x1="14" y1="1" x2="14" y2="3"/><circle cx="14" cy="5.5" r="2.2"/><line x1="14" y1="8" x2="14" y2="16"/></svg>',
    tracking: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><circle cx="8.5" cy="8.5" r="7.3"/><path d="M8.5 4 L8.5 8.5 L11.5 10.5"/></svg>',
    playlists: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><line x1="1" y1="3.5" x2="12" y2="3.5"/><line x1="1" y1="8.5" x2="12" y2="8.5"/><line x1="1" y1="13.5" x2="8" y2="13.5"/><path d="M12.5 10.5 L16 12.5 L12.5 14.5 Z" fill="currentColor"/></svg>',
    info: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="8.5" cy="8.5" r="7.3"/><line x1="8.5" y1="7.5" x2="8.5" y2="12.5" stroke-linecap="round"/><circle cx="8.5" cy="5" r="0.5" fill="currentColor"/></svg>',
    magnifier: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><circle cx="7" cy="7" r="5"/><line x1="11" y1="11" x2="15.5" y2="15.5"/></svg>',
    sliders: '<svg viewBox="0 0 17 17" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><line x1="1.5" y1="4.5" x2="15.5" y2="4.5"/><circle cx="11" cy="4.5" r="2" fill="var(--card)"/><line x1="1.5" y1="12.5" x2="15.5" y2="12.5"/><circle cx="6" cy="12.5" r="2" fill="var(--card)"/></svg>',
  };
  const chev = '<span class="chev"></span>';

  // LibrarySection.libraryTabs: every section but services (those live in the Service Flow menu).
  const LIBRARY_TABS = [
    ['presentations', 'Slides'], ['overlays', 'Overlays'], ['media', 'Media'], ['audio', 'Music'], ['themes', 'Themes'], ['confidence', 'Confidence'],
  ];
  // ServiceControlsModule, the ones that work on Windows first.
  const MODULES = [
    ['overlays', 'Overlays'], ['outputs', 'Outputs'], ['alerts', 'Alerts'], ['confidence', 'Confidence'],
    ['audio', 'Audio'], ['mixer', 'Mixer'], ['media', 'Media'], ['timers', 'Timers'], ['tracking', 'Tracking'], ['combos', 'Combos'],
  ];
  // ShowFunction and LayerKind (RenderEngine), as ClearChip lists them.
  const FUNCTIONS = [['slides', 'Slides', '1'], ['media', 'Media', '2'], ['overlays', 'Overlays', '3'], ['audio', 'Music', '4'], ['alerts', 'Alerts', '5'], ['signage', 'Signage', '6']];
  const LAYERS = [['alerts', 'Alerts'], ['overlays', 'Overlays'], ['slide', 'Slides'], ['videos', 'Foreground Videos'], ['stillGraphics', 'Still Graphics'], ['loopingVideos', 'Background Media'], ['videoInput', 'Video Input']];

  const prefs = {
    get(key, fallback) { try { const v = localStorage.getItem(key); return v == null ? fallback : JSON.parse(v); } catch { return fallback; } },
    set(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch {} },
  };

  const ui = {
    state: null,
    librarySection: prefs.get('library.section', 'presentations'),
    libraryFolder: null,
    selectedEntry: null,
    selectedItem: null,
    module: prefs.get('serviceControls.module', 'overlays'),
    slidesAcross: Math.min(Math.max(prefs.get('slideGrid.slidesAcross', 4), 1), 6),
    roundedCorners: prefs.get('slideGrid.roundedCorners', true),
    transparencyGrid: prefs.get('slideGrid.transparencyGrid', true),
    mode: 'present',
    presentations: new Map(),   // key -> { listing, sequence }
    scenes: new Map(),          // key -> scene
    renderers: new Map(),       // tile key -> renderer
    previewRenderer: null,
    previewVersion: null,
    search: '',
    overlayScope: 'all',
    overlaySearch: null,
    collapsedHeaders: new Set(),
  };

  function librarySequence() { return ui.state ? Math.floor(ui.state.version / 1000) : 0; }
  function kindGlyph(kind) { return { presentation: 'presentations', media: 'media', audio: 'audio', playlist: 'audio', info: 'info' }[kind] || 'presentations'; }

  // ---------- Service Flow (AppShell.serviceHeader + RunOrderList) ----------

  function renderServiceHeader() {
    const service = ui.state.service;
    $('service-name').textContent = service ? service.name : 'Choose…';
    $('service-date').textContent = service && service.date ? formatDate(service.date) : '';
    $('toolbar-service-name').textContent = service ? service.name : '';
    const count = service ? service.items.filter(i => i.kind !== 'header').length : 0;
    $('item-count').textContent = service ? (count === 1 ? '1 item' : `${count} items`) : '';
  }

  function formatDate(iso) {
    const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso || '');
    if (!match) return iso || '';
    const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]));
    return date.toLocaleDateString(undefined, { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' });
  }

  function collapseKey() { return ui.state.service ? `runOrder.collapsed.${ui.state.service.id}` : null; }
  function loadCollapsed() { const key = collapseKey(); ui.collapsedHeaders = new Set(key ? prefs.get(key, []) : []); }

  function renderRunOrder() {
    const list = $('run-order');
    const service = ui.state.service;
    list.innerHTML = '';
    if (!service) {
      list.innerHTML = '<div class="empty"><strong>No Service</strong>Create one from the menu above.</div>';
      return;
    }
    const live = ui.state.live;
    let collapsed = false;
    for (const item of service.items) {
      if (item.kind === 'header') {
        collapsed = ui.collapsedHeaders.has(item.id);
        const row = document.createElement('div');
        row.className = 'run-row header' + (collapsed ? ' collapsed' : '');
        const tint = hex(item.colorHex);
        if (tint) { row.style.setProperty('--tint', tint); row.style.setProperty('--rule', tint + '73'); }
        row.innerHTML = `<span class="disclosure" title="${collapsed ? 'Expand' : 'Collapse'}"></span><span class="rule"></span><span class="title">${escape(item.name)}</span><span class="rule"></span><span class="tail"></span>`;
        row.querySelector('.disclosure').addEventListener('click', (event) => {
          event.stopPropagation();
          if (ui.collapsedHeaders.has(item.id)) ui.collapsedHeaders.delete(item.id); else ui.collapsedHeaders.add(item.id);
          prefs.set(collapseKey(), [...ui.collapsedHeaders]);
          renderRunOrder();
        });
        row.addEventListener('click', () => scrollToItem(item.id));
        list.appendChild(row);
        continue;
      }
      if (collapsed) continue;
      const row = document.createElement('div');
      row.className = 'run-row' + (item.kind === 'info' ? ' info' : '');
      if (item.hidden) row.classList.add('hidden-item');
      if (live && live.contextId === item.id) row.classList.add('live');
      if (ui.selectedItem === item.id) row.classList.add('selected');
      let trailing = '';
      if (item.kind === 'presentation' && item.arrangementId) {
        const listing = ui.presentations.get(`${item.refId}|${item.arrangementId}`);
        const name = listing && listing.listing.arrangements.find(a => a.id === item.arrangementId);
        if (name) trailing += `<span class="arrangement">${escape(name.name)}</span>`;
      }
      if (item.kind !== 'info') trailing += `<span class="kind-glyph">${G[kindGlyph(item.kind)]}</span>`;
      row.innerHTML = `<span class="name" title="${escape(item.name)}">${escape(item.name)}</span>${trailing}`;
      row.addEventListener('click', () => {
        ui.selectedItem = item.id;
        if (ui.selectedEntry) { ui.selectedEntry = null; renderLibraryList(); renderPresentView(); }
        renderRunOrder();
        scrollToItem(item.id);
      });
      list.appendChild(row);
    }
  }

  function scrollToItem(id) {
    const target = document.querySelector(`.deck[data-item="${cssEscape(id)}"], .service-band[data-item="${cssEscape(id)}"], .media-card[data-item="${cssEscape(id)}"]`);
    if (target) target.scrollIntoView({ block: 'start', behavior: 'smooth' });
  }

  // ---------- Libraries (LibrarySidebar) ----------

  function renderLibraryTabs() {
    renderTabRow($('library-tabs'), LIBRARY_TABS.map(([id, title]) => ({ id, title, glyph: id })), ui.librarySection, (id) => {
      ui.librarySection = id;
      ui.libraryFolder = null;
      prefs.set('library.section', id);
      renderLibraryTabs();
      renderLibraryList();
    });
  }

  function sectionTitle(id) { return (LIBRARY_TABS.find(t => t[0] === id) || [id, id])[1]; }

  function renderLibraryList() {
    const list = $('library-list');
    const section = ui.librarySection;
    const all = (ui.state.sections[section] || []).slice();
    const query = ui.search.trim().toLowerCase();
    list.innerHTML = '';
    if (query) {
      const hits = all.filter(e => e.name.toLowerCase().includes(query) || (e.folder || '').toLowerCase().includes(query));
      if (!hits.length) { list.innerHTML = `<div class="empty"><strong>No ${escape(sectionTitle(section))}</strong>Nothing matches the search.</div>`; return; }
      for (const entry of hits) list.appendChild(entryRow(section, entry, true));
      return;
    }
    if (!all.length) {
      const note = section === 'media' || section === 'audio' ? 'Import comes to Windows later.' : 'Editing comes to Windows later.';
      list.innerHTML = `<div class="empty"><strong>No ${escape(sectionTitle(section))}</strong>${note}</div>`;
      return;
    }
    const folders = new Map();
    for (const entry of all) {
      const top = (entry.folder || '').split('/').filter(Boolean)[0] || '';
      if (top) folders.set(top, (folders.get(top) || 0) + 1);
    }
    if (ui.libraryFolder) {
      const back = document.createElement('div');
      back.className = 'list-row';
      back.innerHTML = `<span class="folder-glyph">${G.folder}</span><span class="name">‹ ${escape(ui.libraryFolder)}</span>`;
      back.addEventListener('click', () => { ui.libraryFolder = null; renderLibraryList(); });
      list.appendChild(back);
      for (const entry of all.filter(e => ((e.folder || '').split('/').filter(Boolean)[0] || '') === ui.libraryFolder)) list.appendChild(entryRow(section, entry, false));
      return;
    }
    const allRow = document.createElement('div');
    allRow.className = 'list-row';
    allRow.innerHTML = `<span class="folder-glyph">${G.folder}</span><span class="name">All ${escape(sectionTitle(section))}</span><span class="count">${all.length}</span>`;
    allRow.addEventListener('click', () => { ui.libraryFolder = null; renderLibraryList(); });
    list.appendChild(allRow);
    for (const [name, count] of [...folders].sort((a, b) => a[0].localeCompare(b[0]))) {
      const row = document.createElement('div');
      row.className = 'list-row';
      row.innerHTML = `<span class="folder-glyph">${G.folder}</span><span class="name">${escape(name)}</span><span class="count">${count}</span>`;
      row.addEventListener('click', () => { ui.libraryFolder = name; renderLibraryList(); });
      list.appendChild(row);
    }
    for (const entry of all.filter(e => !((e.folder || '').split('/').filter(Boolean)[0]))) list.appendChild(entryRow(section, entry, false));
  }

  function entryRow(section, entry, showFolder) {
    const row = document.createElement('div');
    row.className = 'list-row' + (ui.selectedEntry === entry.id ? ' selected' : '');
    row.innerHTML = `<span class="name" title="${escape(entry.name)}">${escape(entry.name)}</span>${showFolder && entry.folder ? `<span class="meta">${escape(entry.folder)}</span>` : ''}`;
    row.addEventListener('click', () => selectEntry(section, entry));
    return row;
  }

  function selectEntry(section, entry) {
    ui.selectedEntry = ui.selectedEntry === entry.id ? null : entry.id;
    ui.selectedItem = null;
    renderLibraryList();
    renderRunOrder();
    renderPresentView();
  }

  async function chooseService(id) {
    try { await api.post('/ui/v1/service', { id }); ui.selectedItem = null; ui.selectedEntry = null; ui.libraryFolder = null; await refresh(true); }
    catch (error) { toast(error.message); }
  }

  // ---------- PriorityTabRow ----------
  // Shows as many pills as fit, in order, and an ellipsis for the rest.

  const tabRows = new Map();
  const tabRowObserver = new ResizeObserver((entries) => {
    for (const entry of entries) {
      const spec = tabRows.get(entry.target);
      if (spec) renderTabRow(entry.target, spec.tabs, spec.selectedId, spec.onSelect);
    }
  });

  function renderTabRow(row, tabs, selectedId, onSelect) {
    if (!tabRows.has(row)) tabRowObserver.observe(row);
    tabRows.set(row, { tabs, selectedId, onSelect });
    row.innerHTML = '';
    row.style.justifyContent = '';
    const pills = tabs.map((tab) => {
      const pill = document.createElement('button');
      pill.className = 'tab' + (tab.id === selectedId ? ' selected' : '') + (tab.tint ? ' tinted' : '');
      if (tab.tint) pill.style.setProperty('--tint', tab.tint);
      pill.innerHTML = `${G[tab.glyph] || ''}<span>${escape(tab.title)}</span>`;
      pill.title = tab.title;
      pill.addEventListener('click', () => onSelect(tab.id));
      return pill;
    });
    for (const pill of pills) row.appendChild(pill);
    const available = row.clientWidth - 6;
    const widths = pills.map(p => p.offsetWidth);
    const spacing = 3, ellipsisWidth = 26;
    const needed = (n) => widths.slice(0, n).reduce((a, b) => a + b, 0) + Math.max(0, n - 1) * spacing + (n < tabs.length ? spacing + ellipsisWidth : 0);
    let visible = tabs.length;
    while (visible > 1 && needed(visible) > available) visible--;
    for (let i = visible; i < pills.length; i++) pills[i].remove();
    const overflow = tabs.slice(visible);
    if (overflow.length) {
      const more = document.createElement('button');
      const selectedHidden = overflow.some(t => t.id === selectedId);
      const tinted = overflow.find(t => t.tint);
      more.className = 'tab overflow' + (selectedHidden ? ' selected' : '') + (tinted ? ' tinted' : '');
      if (tinted) more.style.setProperty('--tint', tinted.tint);
      more.innerHTML = G.ellipsis;
      more.title = 'More tabs';
      more.addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
        pop.style.minWidth = '190px';
        const column = document.createElement('div');
        column.className = 'popover-tabs';
        for (const tab of overflow) {
          const pill = document.createElement('button');
          pill.className = 'tab' + (tab.id === selectedId ? ' selected' : '') + (tab.tint ? ' tinted' : '');
          if (tab.tint) pill.style.setProperty('--tint', tab.tint);
          pill.innerHTML = `${G[tab.glyph] || ''}<span>${escape(tab.title)}</span>`;
          pill.addEventListener('click', () => { closePopover(); onSelect(tab.id); });
          column.appendChild(pill);
        }
        pop.appendChild(column);
      }));
      row.appendChild(more);
    }
    if (row.children.length > 1) row.style.justifyContent = 'space-between';
  }

  // ---------- Present view (ServiceContinuousView) ----------

  async function loadPresentation(id, arrangementId) {
    const key = `${id}|${arrangementId || ''}`;
    const cached = ui.presentations.get(key);
    if (cached && cached.sequence === librarySequence()) return cached.listing;
    const listing = await api.get(`/ui/v1/presentations/${encodeURIComponent(id)}${arrangementId ? `?arrangement=${encodeURIComponent(arrangementId)}` : ''}`);
    ui.presentations.set(key, { listing, sequence: librarySequence() });
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
      let listing = null;
      try { listing = await loadPresentation(selected.id, null); } catch {}
      if (token !== presentRenderToken) return;
      if (listing) fragment.appendChild(deckElement(listing, { contextId: selected.id, itemId: null }));
    } else if (state.service) {
      for (const item of state.service.items) {
        if (item.hidden && item.kind !== 'header') continue;
        if (item.kind === 'header') {
          const band = document.createElement('div');
          band.className = 'service-band';
          band.dataset.item = item.id;
          const tint = hex(item.colorHex);
          if (tint) { band.style.setProperty('--tint', tint); band.style.setProperty('--rule', tint + '73'); }
          band.innerHTML = `${item.hidden ? '' : `<span class="title">${escape(item.name)}</span>`}<span class="rule"></span>`;
          fragment.appendChild(band);
        } else if (item.kind === 'presentation') {
          let listing = null;
          try { listing = await loadPresentation(item.refId, item.arrangementId); } catch {}
          if (token !== presentRenderToken) return;
          if (listing) fragment.appendChild(deckElement(listing, { contextId: item.id, itemId: item.id }));
          else fragment.appendChild(unlinkedCard(item));
        } else if (item.kind === 'info') {
          fragment.appendChild(unlinkedCard(item));
        } else {
          fragment.appendChild(mediaCard(item));
        }
      }
    } else {
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
    renderRunOrder();
  }

  function unlinkedCard(item) {
    const card = document.createElement('div');
    card.className = 'media-card';
    card.dataset.item = item.id;
    card.innerHTML = `<span class="name">${escape(item.name)}</span><span class="spacer"></span><span class="deck-chip capsule-chip">Not Linked</span>`;
    return card;
  }

  function mediaCard(item) {
    const card = document.createElement('div');
    card.className = 'media-card';
    card.dataset.item = item.id;
    const note = item.kind === 'media' ? 'Video and image playback are not on Windows yet.' : 'Audio playback is not on Windows yet.';
    card.innerHTML = `<span class="kind-glyph">${G[kindGlyph(item.kind)]}</span><span class="name">${escape(item.name)}</span><span class="spacer"></span><span>${escape(note)}</span>`;
    return card;
  }

  function deckElement(listing, context) {
    const deck = document.createElement('section');
    deck.className = 'deck';
    deck.dataset.presentation = listing.id;
    deck.dataset.context = context.contextId;
    deck.dataset.count = listing.slides.length;
    if (context.itemId) deck.dataset.item = context.itemId;
    const arrangement = listing.arrangements.find(a => a.id === listing.arrangementId);
    const header = document.createElement('div');
    header.className = 'deck-header';
    header.innerHTML = `<div class="deck-header-row"><span class="deck-glyph">${G.presentations}</span><span class="deck-title" title="${escape(listing.name)}">${escape(listing.name)}</span>`
      + (listing.sections.length ? `<span class="deck-chip" title="Which arrangement plays here">${escape(arrangement ? arrangement.name : 'Default')}${chev}</span>` : '')
      + (listing.musicKey ? `<span class="deck-chip capsule-chip">Key ${escape(listing.musicKey)}</span>` : '')
      + `<span class="spacer"></span><span class="deck-detail"></span></div>`;
    // ArrangementStrip: one pill per block of slides that share a section, in play order.
    if (listing.sections.length) {
      const strip = document.createElement('div');
      strip.className = 'arrangement-strip';
      let previous = null;
      listing.slides.forEach((slide, index) => {
        if (!slide.sectionId || slide.sectionId === previous) { previous = slide.sectionId; return; }
        previous = slide.sectionId;
        const pill = document.createElement('button');
        pill.className = 'arrangement-pill' + (arrangement ? ' prominent' : '');
        pill.textContent = slide.sectionName || 'Section';
        const tint = hex(slide.sectionColorHex);
        if (tint) { pill.style.background = arrangement ? tint : tint + '8c'; pill.style.color = textOn(tint); }
        pill.addEventListener('click', () => jumpToSlide(deck, index));
        strip.appendChild(pill);
      });
      if (strip.children.length) header.appendChild(strip);
    }
    deck.appendChild(header);
    const body = document.createElement('div');
    body.className = 'deck-body';
    const grid = document.createElement('div');
    grid.className = 'slide-grid';
    grid.style.gridTemplateColumns = `repeat(${ui.slidesAcross}, minmax(0, 1fr))`;
    let previousSection = null;
    listing.slides.forEach((slide, index) => {
      const tile = document.createElement('div');
      tile.className = 'tile';
      tile.dataset.index = slide.index;
      tile.dataset.presentation = listing.id;
      tile.dataset.context = context.contextId;
      tile.dataset.arrangement = listing.arrangementId || '';
      const frame = document.createElement('div');
      frame.className = 'tile-frame';
      frame.appendChild(document.createElement('canvas'));
      const startsSection = slide.sectionName && (index === 0 || previousSection !== slide.sectionId);
      previousSection = slide.sectionId;
      if (startsSection) {
        const capsule = document.createElement('span');
        capsule.className = 'section-capsule';
        capsule.textContent = slide.sectionName;
        const tint = hex(slide.sectionColorHex);
        if (tint) { capsule.style.background = tint; capsule.style.color = textOn(tint); }
        frame.appendChild(capsule);
      }
      tile.appendChild(frame);
      const label = document.createElement('div');
      label.className = 'tile-label';
      label.innerHTML = `<span class="num">${slide.index + 1}</span>${slide.label ? `<span class="text">${escape(slide.label.slice(0, 30))}</span>` : ''}`;
      tile.appendChild(label);
      tile.title = slide.label || slide.text || '';
      tile.addEventListener('click', () => fire(listing.id, slide.index, context.contextId, listing.arrangementId));
      grid.appendChild(tile);
    });
    body.appendChild(grid);
    deck.appendChild(body);
    return deck;
  }

  // Lands the tile just under the card's sticky header, as the Mac's jumpToBlock does.
  function jumpToSlide(deck, index) {
    const tile = deck.querySelector(`.tile[data-index="${index}"]`);
    if (!tile) return;
    const view = $('present-view');
    const headerHeight = deck.querySelector('.deck-header').offsetHeight;
    const top = tile.getBoundingClientRect().top - view.getBoundingClientRect().top + view.scrollTop;
    view.scrollTo({ top: top - headerHeight - 12, behavior: 'smooth' });
  }

  const tileObserver = new IntersectionObserver((entries) => {
    for (const entry of entries) if (entry.isIntersecting) drawTile(entry.target);
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
    } catch { return null; }
  }

  function redrawTiles() {
    for (const grid of document.querySelectorAll('.slide-grid')) grid.style.gridTemplateColumns = `repeat(${ui.slidesAcross}, minmax(0, 1fr))`;
    for (const tile of document.querySelectorAll('.tile')) tile.dataset.drawn = '';
    observeTiles();
  }

  function updateLiveHighlight() {
    const live = ui.state && ui.state.live;
    for (const tile of document.querySelectorAll('.tile')) {
      tile.classList.toggle('live', !!live && tile.dataset.context === live.contextId && Number(tile.dataset.index) === live.occurrence);
    }
    for (const deck of document.querySelectorAll('.deck')) {
      const detail = deck.querySelector('.deck-detail');
      const count = Number(deck.dataset.count);
      const isLive = !!live && deck.dataset.context === live.contextId;
      detail.textContent = isLive ? `Slide ${live.occurrence + 1} of ${count}` : (count === 1 ? '1 slide' : `${count} slides`);
      detail.classList.toggle('live', isLive);
    }
  }

  function revealLive() {
    const live = ui.state && ui.state.live;
    if (!live) return;
    const tile = [...document.querySelectorAll('.tile')].find(t => t.dataset.context === live.contextId && Number(t.dataset.index) === live.occurrence);
    if (tile) tile.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
  }

  async function fire(presentationId, index, contextId, arrangementId) {
    try { await api.post('/ui/v1/fire', { presentationId, index, contextId, arrangementId: arrangementId || null }); await refresh(true); }
    catch (error) { toast(error.message); }
  }

  async function advance(steps, settled) {
    try { await api.post('/ui/v1/advance', { steps, settled: !!settled }); await refresh(true); revealLive(); }
    catch (error) { toast(error.message); }
  }

  async function clear(body) {
    try { await api.post('/ui/v1/clear', body); await refresh(true); }
    catch (error) { toast(error.message); }
  }

  // ---------- Output Preview (LivePanel) ----------

  let previewAnimating = false;

  async function fetchPreviewScene() {
    const scene = await api.get('/ui/v1/scene/live');
    const canvas = $('preview-canvas');
    const dpr = window.devicePixelRatio || 1;
    const width = Math.round(Math.max(canvas.clientWidth, 200) * dpr);
    if (canvas.width !== width) { canvas.width = width; canvas.height = Math.round(width * 9 / 16); }
    ui.previewRenderer.draw(scene);
    return scene;
  }

  // Builds and exits play on the host clock: while the live scene says it is
  // still moving, keep asking for fresh frames.
  async function animatePreview() {
    if (previewAnimating) return;
    previewAnimating = true;
    const started = performance.now();
    try {
      while (performance.now() - started < 12000) {
        const scene = await fetchPreviewScene();
        if (!scene.timeVarying) break;
        await new Promise(r => setTimeout(r, 66));
      }
    } catch { /* keep the last frame */ }
    finally { previewAnimating = false; }
  }

  async function renderPreview(force) {
    if (!ui.previewRenderer) ui.previewRenderer = new SceneRenderer($('preview-canvas'), { onMediaLoaded: () => {} });
    if (!force && ui.previewVersion === ui.state.version) return;
    ui.previewVersion = ui.state.version;
    try {
      const scene = await fetchPreviewScene();
      if (scene.timeVarying) animatePreview();
    } catch { /* keep the last frame */ }
  }

  function hasClearableContent() {
    const s = ui.state;
    return !!(s && (s.live || Object.keys(s.mediaLayers).length || s.overlays.length || s.alert));
  }

  // ---------- Service Controls (ServiceControlsPanel + modules) ----------

  function moduleTint(id) {
    if (!ui.state) return null;
    if (id === 'overlays' && ui.state.overlays.length) return 'var(--green)';
    if (id === 'alerts' && ui.state.alert) return 'var(--orange)';
    return null;
  }

  function renderModuleTabs() {
    renderTabRow($('module-tabs'), MODULES.map(([id, title]) => ({ id, title, glyph: id, tint: moduleTint(id) })), ui.module, (id) => {
      ui.module = id;
      prefs.set('serviceControls.module', id);
      renderModuleTabs();
      renderModule();
    });
  }

  function renderModule() {
    const body = $('module-body');
    body.innerHTML = '';
    const state = ui.state;
    switch (ui.module) {
      case 'overlays': renderOverlaysModule(body, state); break;
      case 'alerts': renderAlertsModule(body, state); break;
      case 'outputs': renderOutputsModule(body, state); break;
      case 'confidence':
        body.innerHTML = `<div class="readout-label">Current</div><div class="readout-text">${escape(state.live ? (state.live.text || state.live.slideName || '') : '—')}</div><div class="readout-label">Next</div><div class="readout-text next">${escape(state.nextText || (state.live ? 'End of service' : '—'))}</div><div class="module-note">Confidence layouts and the stage display are not on Windows yet; this readout shows what they would.</div>`;
        break;
      default:
        body.innerHTML = `<div class="module-note">${escape(MODULES.find(m => m[0] === ui.module)[1])} is not on Windows yet. It needs the audio, media and timer engines, which are still Mac-only.</div>`;
    }
  }

  function renderOverlaysModule(body, state) {
    const all = state.sections.overlays || [];
    const folders = [...new Set(all.map(o => o.folder).filter(Boolean))].sort();
    const bar = document.createElement('div');
    bar.className = 'module-bar';
    const scopeTitle = ui.overlayScope === 'all' ? 'All' : ui.overlayScope.replace('folder:', '');
    bar.innerHTML = `<button class="quiet-menu" id="overlay-scope">${escape(scopeTitle)}${chev}</button><span class="spacer"></span><button class="icon-button tiny" title="View options (not on Windows yet)" disabled>${G.sliders}</button><button class="icon-button tiny" id="overlay-search" title="Search by name — folder names match too">${G.magnifier}</button>`;
    body.appendChild(bar);
    bar.querySelector('#overlay-scope').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      menuRow(pop, 'All', { current: ui.overlayScope === 'all', action: () => { ui.overlayScope = 'all'; renderModule(); } });
      if (folders.length) {
        pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div><div class="menu-section">Folders</div>');
        for (const folder of folders) menuRow(pop, folder, { current: ui.overlayScope === `folder:${folder}`, action: () => { ui.overlayScope = `folder:${folder}`; renderModule(); } });
      }
    }));
    bar.querySelector('#overlay-search').addEventListener('click', () => { ui.overlaySearch = ui.overlaySearch == null ? '' : null; renderModule(); });
    if (ui.overlaySearch != null) {
      const field = document.createElement('label');
      field.className = 'search';
      field.innerHTML = `<span class="search-glyph"></span><input type="search" placeholder="Search" autocomplete="off" spellcheck="false">`;
      const input = field.querySelector('input');
      input.value = ui.overlaySearch;
      input.addEventListener('input', () => { ui.overlaySearch = input.value; renderOverlayRows(); });
      body.appendChild(field);
      setTimeout(() => input.focus(), 0);
    }
    const rows = document.createElement('div');
    rows.id = 'overlay-rows';
    rows.style.display = 'contents';
    body.appendChild(rows);
    function renderOverlayRows() {
      rows.innerHTML = '';
      const query = (ui.overlaySearch || '').trim().toLowerCase();
      let entries = all;
      if (query) entries = all.filter(o => o.name.toLowerCase().includes(query) || (o.folder || '').toLowerCase().includes(query));
      else if (ui.overlayScope.startsWith('folder:')) entries = all.filter(o => o.folder === ui.overlayScope.slice(7));
      if (!all.length) { rows.innerHTML = '<div class="module-note">Create overlays in Edit → Overlays; they go live from here and persist across slides.</div>'; return; }
      if (!entries.length) { rows.innerHTML = `<div class="module-note">${query ? 'No overlays match.' : 'This folder is empty.'}</div>`; return; }
      const grouped = new Map();
      for (const overlay of entries) {
        const folder = query || ui.overlayScope !== 'all' ? '' : (overlay.folder || '');
        if (!grouped.has(folder)) grouped.set(folder, []);
        grouped.get(folder).push(overlay);
      }
      for (const [folder, list] of grouped) {
        if (folder) rows.insertAdjacentHTML('beforeend', `<div class="module-folder">${escape(folder.replace(/\//g, ' / '))}</div>`);
        for (const overlay of list) rows.appendChild(overlayRow(overlay, state));
      }
    }
    renderOverlayRows();
  }

  function overlayRow(overlay, state) {
    const live = state.overlays.some(o => o.id === overlay.id);
    const row = document.createElement('div');
    row.className = 'rack-row' + (live ? ' live' : '');
    row.innerHTML = `<span class="name">${escape(overlay.name)}</span><button class="rack-chip">${live ? 'Take Down' : 'Go Live'}</button>`;
    const toggle = async (event) => {
      if (event) event.stopPropagation();
      try { await api.post('/ui/v1/overlay', { id: overlay.id, action: live ? 'dismiss' : 'fire' }); await refresh(true); }
      catch (error) { toast(error.message); }
    };
    row.querySelector('.rack-chip').addEventListener('click', toggle);
    row.addEventListener('click', () => { if (!live) toggle(); });
    row.title = live ? 'Take this overlay down' : 'Go live — persists across slides';
    return row;
  }

  function renderAlertsModule(body, state) {
    const live = state.alert;
    body.insertAdjacentHTML('beforeend', '<div class="module-section">Ad-hoc alert</div>');
    const field = document.createElement('textarea');
    field.className = 'field';
    field.rows = 3;
    field.placeholder = 'Message for the audience screen';
    field.value = live ? live.message : '';
    body.appendChild(field);
    const target = document.createElement('select');
    target.className = 'field';
    target.innerHTML = '<option value="audience">Audience</option><option value="both">Audience + Confidence</option><option value="confidence">Confidence only</option>';
    body.appendChild(target);
    const buttons = document.createElement('div');
    buttons.className = 'module-row';
    const fireButton = document.createElement('button');
    fireButton.className = 'card-button primary';
    fireButton.textContent = 'Fire Alert';
    fireButton.addEventListener('click', async () => {
      try { await api.post('/ui/v1/alert', { message: field.value, target: target.value, behavior: 'persist' }); await refresh(true); }
      catch (error) { toast(error.message); }
    });
    const dismiss = document.createElement('button');
    dismiss.className = 'card-button destructive';
    dismiss.textContent = 'Dismiss';
    dismiss.disabled = !live;
    dismiss.addEventListener('click', async () => { try { await api.post('/ui/v1/alert', { dismiss: true }); await refresh(true); } catch (error) { toast(error.message); } });
    buttons.append(fireButton, dismiss);
    body.appendChild(buttons);
    if (live) body.insertAdjacentHTML('beforeend', `<div class="module-note">Live: “${escape(live.message)}” (${escape(live.target)})</div>`);
    body.insertAdjacentHTML('beforeend', '<div class="module-note">Saved alerts and alert folders come to Windows later.</div>');
  }

  // OutputsModule: each display gets the audience output as a borderless,
  // full-screen window; the host's own window opens and closes them.
  function renderOutputsModule(body, state) {
    body.insertAdjacentHTML('beforeend', '<div class="module-section">Screens</div>');
    if (state.nativeWindow && state.displays.length) {
      for (const display of state.displays) {
        const output = state.outputs.find(o => o.display === display.index);
        const row = document.createElement('div');
        row.className = 'rack-row' + (output ? ' live' : '');
        row.innerHTML = `<span class="kind-glyph">${G.screens}</span><span class="name" title="${display.width} × ${display.height} at ${display.x}, ${display.y}">${escape(display.name)}${display.isPrimary ? ' · main' : ''}</span><button class="rack-chip shown">${output ? 'Close' : 'Send Output'}</button>`;
        row.querySelector('.rack-chip').addEventListener('click', async (event) => {
          event.stopPropagation();
          try { await api.post('/ui/v1/output', output ? { action: 'close', id: output.id } : { action: 'open', display: display.index }); await refresh(true); }
          catch (error) { toast(error.message); }
        });
        body.appendChild(row);
      }
      body.insertAdjacentHTML('beforeend', '<div class="module-note">The output fills the display and stays above other windows there. On the display with this window it stays behind the app so you can get back.</div>');
    } else {
      body.insertAdjacentHTML('beforeend', '<div class="module-note">Open the output in its own window and drag it to the projector or second display. Double-click it for full screen.</div>');
    }
    const open = document.createElement('button');
    open.className = 'card-button wide';
    open.textContent = 'Open Output in a Window';
    open.addEventListener('click', openOutputWindow);
    body.appendChild(open);
    body.insertAdjacentHTML('beforeend', '<div class="module-note">Screen roles, NDI, DeckLink and output presets are not on Windows yet.</div>');
    if (state.localAPIPort) {
      body.insertAdjacentHTML('beforeend', `<div class="module-section">Local API</div><div class="module-note">Remotes and control surfaces connect to this computer on port ${state.localAPIPort} with the default key.</div>`);
      if (state.localAPIKey) {
        const row = document.createElement('div');
        row.className = 'module-row';
        row.innerHTML = `<code class="key-text" title="${escape(state.localAPIKey)}">${escape(state.localAPIKey)}</code>`;
        const copy = document.createElement('button');
        copy.className = 'card-button';
        copy.textContent = 'Copy';
        copy.addEventListener('click', async () => {
          try { await navigator.clipboard.writeText(state.localAPIKey); toast('Key copied.'); }
          catch { toast('Could not copy; select the key and copy it.'); }
        });
        row.appendChild(copy);
        body.appendChild(row);
      }
    }
  }

  function outputsKey(state) { return JSON.stringify([state.displays, state.outputs]); }

  function renderPreviewTarget() {
    const state = ui.state;
    const primary = state.displays.find(d => d.isPrimary) || state.displays[0];
    $('preview-target-name').textContent = primary ? primary.name : 'Audience';
  }

  function openOutputWindow() { window.open('/output', 'mxu-output', 'popup=yes,width=960,height=540'); }

  // ---------- Popovers and menus ----------

  function popover(anchor, build) {
    const pop = $('popover');
    pop.innerHTML = '';
    pop.style.minWidth = '';
    build(pop);
    pop.hidden = false;
    const rect = anchor.getBoundingClientRect();
    pop.style.left = `${Math.max(8, Math.min(rect.left, window.innerWidth - pop.offsetWidth - 8))}px`;
    pop.style.top = `${Math.min(rect.bottom + 6, window.innerHeight - pop.offsetHeight - 8)}px`;
    const close = (event) => { if (!pop.contains(event.target) && !anchor.contains(event.target)) { closePopover(); } };
    pop.closeHandler = close;
    setTimeout(() => document.addEventListener('mousedown', close, true), 0);
  }

  function closePopover() {
    const pop = $('popover');
    pop.hidden = true;
    if (pop.closeHandler) { document.removeEventListener('mousedown', pop.closeHandler, true); pop.closeHandler = null; }
  }

  function menuRow(pop, label, { current, action, date, destructive, disabled, plain, key } = {}) {
    const row = document.createElement('div');
    row.className = 'menu-row' + (current ? ' current' : '') + (destructive ? ' destructive' : '') + (disabled ? ' disabled' : '') + (plain ? ' plain' : '');
    row.innerHTML = `<span>${escape(label)}</span>${date ? `<span class="date">${escape(date)}</span>` : ''}${key ? `<span class="key">${escape(key)}</span>` : ''}`;
    if (action && !disabled) row.addEventListener('click', () => { closePopover(); action(); });
    pop.appendChild(row);
    return row;
  }

  function toggleRow(pop, label, { checked, disabled, onChange } = {}) {
    const row = document.createElement('label');
    row.className = 'menu-row plain' + (disabled ? ' disabled' : '');
    row.innerHTML = `<span>${escape(label)}</span><input type="checkbox"${checked ? ' checked' : ''}${disabled ? ' disabled' : ''}>`;
    if (onChange) row.querySelector('input').addEventListener('change', (event) => onChange(event.target.checked));
    pop.appendChild(row);
    return row;
  }

  function wireToolbar() {
    $('sidebar-toggle').innerHTML = G.sidebar;
    $('view-options').innerHTML = G.viewOptions;
    $('transition-media').innerHTML = G.media;
    $('transition-slide').innerHTML = G.presentations;
    $('broadcast-chip').innerHTML = G.broadcast;
    $('preset-chip').innerHTML = `${G.screens}<span>Default — All…</span>`;
    $('clear-chip').innerHTML = `${G.clear}<span>Clear</span>`;
    $('library-filter').innerHTML = G.filter;
    $('library-view-mode').innerHTML = G.list;
    $('module-popout').innerHTML = G.popout;

    $('sidebar-toggle').addEventListener('click', () => {
      const hidden = $('shell').classList.toggle('sidebar-hidden');
      $('toolbar-service-name').hidden = !hidden;
      prefs.set('shell.sidebarVisible', !hidden);
    });
    if (prefs.get('shell.sidebarVisible', true) === false) { $('shell').classList.add('sidebar-hidden'); $('toolbar-service-name').hidden = false; }

    $('service-menu').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      const today = new Date().toISOString().slice(0, 10);
      const services = ui.state.services.slice();
      const current = services.filter(s => !s.date || s.date >= today).sort((a, b) => (a.date || '9').localeCompare(b.date || '9') || a.name.localeCompare(b.name));
      const earlier = services.filter(s => s.date && s.date < today).sort((a, b) => b.date.localeCompare(a.date));
      if (!services.length) menuRow(pop, 'No services yet', { disabled: true, plain: true });
      for (const service of current) menuRow(pop, service.name, { current: ui.state.service && ui.state.service.id === service.id, date: service.date ? service.date.slice(5) : '', action: () => chooseService(service.id) });
      if (earlier.length) {
        pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div><div class="menu-section">Earlier</div>');
        for (const service of earlier.slice(0, 12)) menuRow(pop, service.name, { current: ui.state.service && ui.state.service.id === service.id, date: service.date.slice(0, 10), action: () => chooseService(service.id) });
      }
      pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div>');
      menuRow(pop, 'New Service…', { disabled: true, plain: true });
    }));
    $('service-date').addEventListener('click', () => toast('Changing the service date comes to Windows later.'));

    $('mode-switcher').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      for (const [mode, title] of [['present', 'Present'], ['edit', 'Edit'], ['scheduler', 'Scheduler']]) menuRow(pop, title, { current: ui.mode === mode, action: () => setMode(mode) });
    }));

    $('view-options').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      pop.style.minWidth = '280px';
      const row = document.createElement('label');
      row.className = 'menu-row plain';
      row.innerHTML = `<span>Slides Across</span><input type="range" min="1" max="6" step="1" value="${ui.slidesAcross}"><span class="date">${ui.slidesAcross}</span>`;
      const input = row.querySelector('input');
      input.addEventListener('input', () => {
        ui.slidesAcross = Number(input.value);
        prefs.set('slideGrid.slidesAcross', ui.slidesAcross);
        row.querySelector('.date').textContent = input.value;
        redrawTiles();
      });
      pop.appendChild(row);
      pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div>');
      toggleRow(pop, 'Continuous Service View', { checked: true, disabled: true });
      pop.insertAdjacentHTML('beforeend', '<div class="menu-section">Thumbnails</div>');
      toggleRow(pop, 'Rounded Corners', { checked: ui.roundedCorners, onChange: (on) => { ui.roundedCorners = on; prefs.set('slideGrid.roundedCorners', on); applyViewPrefs(); } });
      toggleRow(pop, 'Readable Text', { checked: false, disabled: true });
      toggleRow(pop, 'Backgrounds Only on Declaring Slide', { checked: false, disabled: true });
      toggleRow(pop, 'Transparency Grid', { checked: ui.transparencyGrid, onChange: (on) => { ui.transparencyGrid = on; prefs.set('slideGrid.transparencyGrid', on); applyViewPrefs(); } });
      pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div>');
      toggleRow(pop, 'Performance HUD', { checked: false, disabled: true });
      pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div>');
      menuRow(pop, $('shell').classList.contains('rail-hidden') ? 'Show Right Panels' : 'Hide Right Panels', { plain: true, action: () => { const hidden = $('shell').classList.toggle('rail-hidden'); prefs.set('shell.railVisible', !hidden); } });
    }));
    if (prefs.get('shell.railVisible', true) === false) $('shell').classList.add('rail-hidden');

    const transitionMenu = (anchor, layer, kinds, current, duration) => popover(anchor, (pop) => {
      pop.insertAdjacentHTML('beforeend', `<div class="menu-section">${layer} transition</div>`);
      for (const kind of kinds) menuRow(pop, kind, { current: kind === current, disabled: true });
      if (duration) menuRow(pop, `Duration ${duration}`, { plain: true, disabled: true });
      pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div><div class="module-note" style="padding:2px 6px 4px">The output window cuts between looks on Windows; dissolves come with the native output engine.</div>');
    });
    $('transition-media').addEventListener('click', (event) => transitionMenu(event.currentTarget, 'Media', ['Cut', 'Dissolve', 'Fade Black', 'Fade White', 'Blur Dissolve'], 'Dissolve', '0.7s'));
    $('transition-slide').addEventListener('click', (event) => transitionMenu(event.currentTarget, 'Slide', ['Cut', 'Dissolve', 'Fade Black', 'Fade White', 'Blur Dissolve'], 'Cut', null));

    $('broadcast-chip').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      pop.insertAdjacentHTML('beforeend', '<div class="menu-section">Stream &amp; Record</div>');
      menuRow(pop, 'Start Streaming…', { disabled: true, plain: true });
      menuRow(pop, 'Start Recording…', { disabled: true, plain: true });
      pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div><div class="module-note" style="padding:2px 6px 4px">Streaming and recording are not on Windows yet.</div>');
    }));

    $('preset-chip').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      menuRow(pop, 'Default — All Layers', { current: true });
      pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div>');
      menuRow(pop, 'Edit Output Presets…', { disabled: true, plain: true });
    }));

    $('clear-chip').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      pop.style.minWidth = '230px';
      const all = document.createElement('div');
      all.className = 'wide-row';
      const button = document.createElement('button');
      button.className = 'card-button wide' + (hasClearableContent() ? ' destructive' : '');
      button.textContent = 'Clear All';
      button.addEventListener('click', () => { closePopover(); clear({ all: true }); });
      all.appendChild(button);
      pop.appendChild(all);
      pop.insertAdjacentHTML('beforeend', '<div class="menu-section">Functions</div>');
      const grid = document.createElement('div');
      grid.className = 'popover-grid';
      for (const [fn, title] of FUNCTIONS) {
        const b = document.createElement('button');
        b.className = 'card-button';
        b.textContent = title;
        b.addEventListener('click', () => { closePopover(); clear({ function: fn }); });
        grid.appendChild(b);
      }
      pop.appendChild(grid);
      pop.insertAdjacentHTML('beforeend', '<div class="menu-section">Layers</div>');
      for (const [layer, title] of LAYERS) menuRow(pop, title, { plain: true, action: () => clear({ layer }) });
    }));

    $('preview-target').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      pop.insertAdjacentHTML('beforeend', '<div class="menu-section">Screens</div>');
      const displays = ui.state.displays;
      if (displays.length) {
        const primary = displays.find(d => d.isPrimary) || displays[0];
        for (const display of displays) {
          const output = ui.state.outputs.find(o => o.display === display.index);
          menuRow(pop, display.name + (output ? ' · live' : ''), { current: display === primary, action: () => { ui.module = 'outputs'; prefs.set('serviceControls.module', 'outputs'); renderModuleTabs(); renderModule(); } });
        }
      } else {
        menuRow(pop, 'Audience', { current: true });
      }
      pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div>');
      menuRow(pop, 'Open in Window', { plain: true, action: openOutputWindow });
    }));

    $('library-search').addEventListener('input', (event) => { ui.search = event.target.value; renderLibraryList(); });
    $('library-filter').addEventListener('click', (event) => popover(event.currentTarget, (pop) => {
      pop.insertAdjacentHTML('beforeend', '<div class="menu-section">Search in</div>');
      menuRow(pop, 'All Libraries', { current: true });
      pop.insertAdjacentHTML('beforeend', '<div class="menu-divider"></div>');
      toggleRow(pop, 'Used in an Upcoming Service', { checked: false, disabled: true });
    }));
    $('library-view-mode').addEventListener('click', () => toast('The grid view comes to Windows later.'));

    $('present-view').addEventListener('mousedown', () => $('present-view').focus());
    document.addEventListener('keydown', (event) => {
      const typing = ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement && document.activeElement.tagName);
      if (event.key === 'Escape') { closePopover(); if (typing) document.activeElement.blur(); return; }
      if (typing) return;
      if (event.key === 'ArrowRight' || event.key === ' ' || event.key === 'Enter') { event.preventDefault(); advance(1, event.altKey); }
      else if (event.key === 'ArrowLeft') { event.preventDefault(); advance(-1); }
      else if ((event.ctrlKey || event.metaKey) && event.key === 'f') { event.preventDefault(); $('library-search').focus(); }
    });

    wireGrips();
    applyViewPrefs();
  }

  function applyViewPrefs() {
    $('shell').classList.toggle('square-tiles', !ui.roundedCorners);
    $('shell').classList.toggle('transparency-grid', ui.transparencyGrid);
  }

  // The sidebar/library split and the panel widths, as AppShell's grips.
  function wireGrips() {
    const shell = $('shell');
    const sidebarWidth = prefs.get('shell.sidebarWidth', 272);
    const railWidth = prefs.get('shell.rightRailWidth', 280);
    shell.style.setProperty('--sidebar-width', `${sidebarWidth}px`);
    shell.style.setProperty('--rail-width', `${railWidth}px`);
    const splitFraction = prefs.get('shell.sidebarSplit', 0.42);
    $('service-panel').style.flex = `0 0 ${Math.round(splitFraction * 100)}%`;

    let drag = null;
    const start = (kind, event) => { drag = { kind, x: event.clientX, y: event.clientY, start: null }; event.preventDefault(); };
    $('sidebar-grip').addEventListener('mousedown', (event) => { start('split', event); drag.start = $('service-panel').getBoundingClientRect().height; });
    const sideGrip = document.createElement('div');
    sideGrip.className = 'width-grip';
    $('sidebar').appendChild(sideGrip);
    sideGrip.addEventListener('mousedown', (event) => { start('sidebar', event); drag.start = $('sidebar').getBoundingClientRect().width; });
    const railGrip = document.createElement('div');
    railGrip.className = 'width-grip';
    $('rail').appendChild(railGrip);
    railGrip.addEventListener('mousedown', (event) => { start('rail', event); drag.start = $('rail').getBoundingClientRect().width; });
    const railSplit = $('rail-grip');
    railSplit.addEventListener('mousedown', (event) => { start('railSplit', event); drag.start = $('preview-panel').getBoundingClientRect().height; });

    window.addEventListener('mousemove', (event) => {
      if (!drag) return;
      if (drag.kind === 'split') {
        const total = $('sidebar').getBoundingClientRect().height - 16;
        const next = Math.min(Math.max(drag.start + event.clientY - drag.y, 170), total - 180);
        $('service-panel').style.flex = `0 0 ${next}px`;
        drag.value = next / total;
      } else if (drag.kind === 'railSplit') {
        const total = $('rail').getBoundingClientRect().height - 16;
        const next = Math.min(Math.max(drag.start + event.clientY - drag.y, 200), total - 180);
        $('preview-panel').style.flex = `0 0 ${next}px`;
      } else if (drag.kind === 'sidebar') {
        const next = Math.min(Math.max(drag.start + event.clientX - drag.x, 272), 420);
        shell.style.setProperty('--sidebar-width', `${next}px`);
        drag.value = next;
      } else if (drag.kind === 'rail') {
        const next = Math.min(Math.max(drag.start - (event.clientX - drag.x), 240), 480);
        shell.style.setProperty('--rail-width', `${next}px`);
        drag.value = next;
      }
    });
    window.addEventListener('mouseup', () => {
      if (!drag) return;
      if (drag.kind === 'split' && drag.value) prefs.set('shell.sidebarSplit', drag.value);
      if (drag.kind === 'sidebar' && drag.value) prefs.set('shell.sidebarWidth', drag.value);
      if (drag.kind === 'rail' && drag.value) prefs.set('shell.rightRailWidth', drag.value);
      if (drag.kind === 'sidebar' || drag.kind === 'rail') redrawTiles();
      drag = null;
    });
  }

  function setMode(mode) {
    ui.mode = mode;
    $('mode-title').textContent = { present: 'Present', edit: 'Edit', scheduler: 'Scheduler' }[mode];
    $('edit-contexts').hidden = mode !== 'edit';
    $('present-chips').hidden = mode !== 'present';
    $('shell').classList.toggle('rail-hidden', mode === 'edit' || prefs.get('shell.railVisible', true) === false);
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
      const changed = force || first || state.version !== ui.state.version;
      const libraryChanged = first || Math.floor(state.version / 1000) !== Math.floor(ui.state.version / 1000);
      const serviceChanged = first || JSON.stringify(state.service) !== JSON.stringify(ui.state.service);
      const outputsChanged = first || outputsKey(state) !== outputsKey(ui.state);
      ui.state = state;
      if (first) { loadCollapsed(); renderLibraryTabs(); renderModuleTabs(); }
      if (outputsChanged) {
        renderPreviewTarget();
        if (!changed && ui.module === 'outputs') renderModule();
      }
      if (changed) {
        if (serviceChanged) loadCollapsed();
        renderServiceHeader();
        if (libraryChanged) { ui.scenes.clear(); renderLibraryList(); }
        if (serviceChanged || libraryChanged) await renderPresentView(); else updateLiveHighlight();
        renderRunOrder();
        renderModuleTabs();
        renderModule();
        $('clear-chip').classList.toggle('armed', hasClearableContent());
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
    return m ? `#${m[1]}` : null;
  }
  function textOn(color) {
    const r = parseInt(color.slice(1, 3), 16), g = parseInt(color.slice(3, 5), 16), b = parseInt(color.slice(5, 7), 16);
    return (0.299 * r + 0.587 * g + 0.114 * b) > 150 ? '#1a1a1a' : '#fff';
  }

  wireToolbar();
  setMode('present');
  refresh(true);
  setInterval(() => refresh(), 300);
  window.addEventListener('resize', () => { ui.previewVersion = null; redrawTiles(); });
})();

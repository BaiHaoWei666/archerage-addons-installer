'use strict';

// ---------- 小工具 ----------

const ICON = {
  hex: '<path d="M12 2.5l8.5 4.9v9.2L12 21.5l-8.5-4.9V7.4z"/>',
  download: '<path d="M12 3v12"/><path d="M7 10l5 5 5-5"/><path d="M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-2"/>',
  gear: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>',
  refresh: '<path d="M21 12a9 9 0 0 1-15.5 6.2L3 16"/><path d="M3 12a9 9 0 0 1 15.5-6.2L21 8"/><path d="M21 3v5h-5"/><path d="M3 21v-5h5"/>',
  folder: '<path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>',
  trash: '<path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="M6 6l1 14h10l1-14"/><path d="M10 11v5M14 11v5"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/>',
  x: '<path d="M6 6l12 12M18 6L6 18"/>',
  check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  alert: '<path d="M10.3 3.9L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4"/><path d="M12 17h.01"/>',
  chevron: '<path d="M6 9l6 6 6-6"/>',
};

const LOGO = '<img src="logo.png" alt="ArcheRage">';

const $ = sel => document.querySelector(sel);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const svg = (name, cls = '') => `<svg class="ico ${cls}" viewBox="0 0 24 24" aria-hidden="true">${ICON[name]}</svg>`;
// 呼叫 Go 後端（app.go 的 App.Handle）
const post = msg => {
  const handle = window.go?.main?.App?.Handle;
  if (handle) handle(msg).catch(err => toast('error', String(err)));
};

// ---------- 狀態 ----------

const S = {
  view: 'browse',       // browse | installed | settings
  selected: null,       // 選取的插件名稱
  search: '',
  category: '',
  sort: 'updated',
  data: null,           // Go 傳來的 state
  generation: -1,
  details: {},          // 名稱 → 說明 HTML（undefined = 載入中，null = 沒有）
  brokenIcons: new Set(),
  busy: null,           // 忙碌提示：文字、百分比及下載統計
  showOlder: false,
};

const needsUpdate = a => a.status === 'update' || a.status === 'unknown';
const addons = () => S.data?.addons ?? [];
const find = name => addons().find(a => a.name === name);

function hue(name) {
  let h = 0;
  for (const c of name) h = (h * 31 + c.charCodeAt(0)) % 360;
  return h;
}

function fallbackIcon(a) {
  return `<span class="icon fallback" style="--h:${hue(a.name)}">${esc(a.title.charAt(0).toUpperCase())}</span>`;
}

function iconHtml(a, size) {
  const inner = S.brokenIcons.has(a.name)
    ? fallbackIcon(a)
    : `<img class="icon" src="remote/${encodeURIComponent(a.name)}.png?g=${S.generation}" data-name="${esc(a.name)}" alt="">`;
  const check = a.installed ? `<span class="icon-check">${svg('check')}</span>` : '';
  return `<span class="icon-wrap ${size}">${inner}${check}</span>`;
}

// 沒有圖示時改用文字圖示
document.addEventListener('error', e => {
  const img = e.target;
  if (img.tagName !== 'IMG' || !img.classList.contains('icon')) return;
  const a = find(img.dataset.name);
  S.brokenIcons.add(img.dataset.name);
  if (a) img.outerHTML = fallbackIcon(a);
}, true);

// ---------- 畫面 ----------

function render() {
  renderNav();
  const settings = S.view === 'settings';
  $('#listPane').hidden = settings;
  $('#detailPane').hidden = settings;
  $('#settingsPane').hidden = !settings;
  if (settings) {
    renderSettings();
  } else {
    renderList();
    renderDetail();
  }
}

function renderNav() {
  document.querySelectorAll('.nav-btn').forEach(b => b.classList.toggle('active', b.dataset.view === S.view));
  const updates = addons().filter(a => a.installed && needsUpdate(a)).length;
  const badge = $('#updateBadge');
  badge.hidden = !updates;
  badge.textContent = updates;
  $('#selfBadge').hidden = !S.data?.installer?.hasUpdate;
  $('#appVersion').textContent = S.data ? `v${S.data.installer.current}` : '';
}

function visibleAddons() {
  const q = S.search.trim().toLowerCase();
  let list = addons().filter(a => S.view !== 'installed' || a.installed);
  if (S.category) list = list.filter(a => (a.category || '') === S.category);
  if (q) {
    list = list.filter(a => [a.title, a.name, a.description, a.category, a.author]
      .some(v => (v || '').toLowerCase().includes(q)));
  }
  const byName = (x, y) => x.title.localeCompare(y.title, 'zh-Hant');
  const rank = a => (needsUpdate(a) && a.installed ? 0 : a.installed ? 1 : 2);
  const sorters = {
    name: byName,
    updated: (x, y) => (y.updated || '').localeCompare(x.updated || '') || byName(x, y),
    status: (x, y) => rank(x) - rank(y) || byName(x, y),
  };
  return list.sort(sorters[S.sort] || byName);
}

function renderList() {
  const d = S.data;
  const all = addons();
  const installed = all.filter(a => a.installed);
  const updates = installed.filter(needsUpdate);
  const isInstalled = S.view === 'installed';
  const busy = !!S.busy;

  $('#listTitle').textContent = isInstalled ? '已安裝' : '瀏覽';
  $('#listSub').innerHTML = !d?.loaded ? ''
    : isInstalled
      ? `已安裝 ${installed.length} 個` + (updates.length ? ` · <span class="warn-text">${updates.length} 個可更新</span>` : '')
      : `共 ${all.length} 個插件`;

  const updateAll = $('#updateAllBtn');
  updateAll.hidden = !(isInstalled && updates.length);
  updateAll.innerHTML = `${svg('download')}全部更新（${updates.length}）`;
  updateAll.disabled = busy || !d?.dirOk;
  $('#refreshBtn').disabled = busy;
  $('#refreshBtn').classList.toggle('spinning', busy && !d?.loaded);

  // 分類選單
  const categories = [...new Set(all.map(a => a.category).filter(Boolean))].sort((x, y) => x.localeCompare(y, 'zh-Hant'));
  const select = $('#category');
  const key = categories.join('|');
  if (select.dataset.key !== key) {
    select.innerHTML = '<option value="">全部分類</option>' + categories.map(c => `<option>${esc(c)}</option>`).join('');
    select.dataset.key = key;
    if (!categories.includes(S.category)) S.category = '';
    select.value = S.category;
  }

  const list = $('#list');
  const scroll = list.scrollTop;
  let html = '';
  if (!d?.loaded) {
    html = d?.error
      ? `<div class="notice error">${svg('alert')}<div><b>無法載入插件清單</b><span>${esc(d.error)}</span></div><button class="btn small" data-act="refresh"${busy ? ' disabled' : ''}>重試</button></div>`
      : '<div class="list-empty"><span class="spinner"></span><div>正在載入插件清單…</div></div>';
  } else {
    if (!d.dirOk) {
      html += `<div class="notice warn">${svg('alert')}<div><b>找不到插件資料夾</b><span>請到設定選擇 ArcheRage 的 Addon 資料夾。</span></div><button class="btn small" data-act="nav" data-view="settings">設定</button></div>`;
    }
    for (const warning of d.warnings || []) {
      html += `<div class="notice warn">${svg("alert")}<div><b>注意事項</b><span>${esc(warning)}</span></div></div>`;
    }
    const items = visibleAddons();
    if (!items.length) {
      const text = isInstalled && !installed.length ? '還沒有安裝任何插件。' : '沒有符合條件的插件。';
      html += `<div class="list-empty">${text}</div>`;
    }
    html += items.map(rowHtml).join('');
  }
  list.innerHTML = html;
  list.scrollTop = scroll;
}

function rowHtml(a) {
  const isInstalled = S.view === 'installed';
  const meta = [];
  if (isInstalled) {
    meta.push(needsUpdate(a) ? `v${esc(a.localVersion ?? '?')} → v${esc(a.version)}` : `v${esc(a.localVersion)}`);
  }
  if (a.category) meta.push(esc(a.category));
  if (a.author) meta.push(esc(a.author));
  if (!isInstalled) meta.push(`v${esc(a.version)}`);

  const flag = needsUpdate(a) && a.installed
    ? (isInstalled ? '<span class="tag warn">可更新</span>' : '<span class="dot" title="可更新"></span>')
    : '';
  const trash = isInstalled
    ? `<span class="row-act" data-act="uninstall" data-name="${esc(a.name)}" title="解除安裝" role="button">${svg('trash')}</span>`
    : '';
  const selected = a.name === S.selected ? ' selected' : '';
  return `<div class="row${selected}" data-act="select" data-name="${esc(a.name)}" role="button" tabindex="0">
    ${iconHtml(a, 'md')}
    <div class="row-main">
      <div class="row-title"><span>${esc(a.title)}</span>${flag}</div>
      <div class="row-meta">${meta.join('<i>·</i>')}</div>
    </div>
    ${trash}
  </div>`;
}

function renderDetail() {
  const pane = $('#detailPane');
  const a = S.selected && find(S.selected);
  if (!a) {
    const n = addons().length;
    const isInstalled = S.view === 'installed';
    pane.innerHTML = `<div class="empty-state">
      <div class="empty-icon">${svg(isInstalled ? 'download' : 'hex')}</div>
      <h2>${isInstalled ? '選擇一個已安裝的插件' : '選擇一個插件開始'}</h2>
      <p>${n ? `共 ${n} 個插件。從左邊的清單選一個，就能查看說明和更新紀錄，或進行安裝。`
             : '插件清單載入後，就能在這裡查看說明和更新紀錄。'}</p>
    </div>`;
    delete pane.dataset.name;
    return;
  }

  const body = pane.querySelector('.detail-body');
  const scroll = pane.dataset.name === a.name && body ? body.scrollTop : 0;

  const d = S.data;
  const busy = !!S.busy;
  const name = esc(a.name);

  let stateChip;
  if (a.status === 'notInstalled') stateChip = '<span class="chip muted">未安裝</span>';
  else if (a.status === 'latest') stateChip = `<span class="chip ok">${svg('check')}已安裝 v${esc(a.localVersion)}</span>`;
  else stateChip = `<span class="chip warn">可更新：v${esc(a.localVersion ?? '?')} → v${esc(a.version)}</span>`;

  const log = a.changelog || [];
  let logHtml;
  if (!log.length) {
    logHtml = '<div class="muted-text">沒有更新紀錄。</div>';
  } else {
    logHtml = log.slice(0, S.showOlder ? log.length : 1).map((c, i) => `
      <div class="log-entry">
        <div class="log-head">
          ${i === 0 ? '<span class="tag ok">最新</span>' : ''}
          <span class="log-ver">v${esc(c.version)}</span>
          <span class="log-date">${esc(c.date || '')}</span>
        </div>
        <ul>${(c.notes || []).map(n => `<li>${esc(n)}</li>`).join('')}</ul>
      </div>`).join('');
    if (log.length > 1) {
      logHtml += `<button class="log-toggle" data-act="toggleOlder">
        ${S.showOlder ? '收起較舊的紀錄' : `顯示較舊的 ${log.length - 1} 筆紀錄`}${svg('chevron', S.showOlder ? 'flip' : '')}
      </button>`;
    }
  }

  const det = S.details[a.name];
  const description = det === undefined
    ? '<div class="loading-line"><span class="spinner sm"></span>正在載入說明…</div>'
    : det ? `<div class="md">${det}</div>` : '<div class="muted-text">沒有說明。</div>';

  const disabled = busy || !d.dirOk ? ' disabled' : '';
  let primary;
  if (a.status === 'notInstalled') {
    primary = `<button class="btn primary" data-act="install" data-name="${name}"${disabled}>${svg('download')}安裝</button>`;
  } else if (needsUpdate(a)) {
    primary = `<button class="btn primary" data-act="install" data-name="${name}"${disabled}>${svg('download')}更新到 v${esc(a.version)}</button>`;
  } else {
    primary = `<button class="btn ghost" data-act="install" data-name="${name}"${disabled}>${svg('refresh')}重新安裝</button>`;
  }
  const installedButtons = a.installed
    ? `<button class="btn ghost" data-act="openDir" data-name="${name}">${svg('folder')}開啟資料夾</button>
       <button class="btn danger" data-act="uninstall" data-name="${name}"${busy ? ' disabled' : ''}>${svg('trash')}解除安裝</button>`
    : '';

  pane.innerHTML = `
    <header class="detail-head">
      ${iconHtml(a, 'lg')}
      <div class="detail-title">
        <h2>${esc(a.title)}<span class="ver">v${esc(a.version)}</span></h2>
        <div class="by">${a.author ? `by ${esc(a.author)}` : name}</div>
      </div>
      <button class="icon-btn" data-act="close" title="關閉（Esc）">${svg('x')}</button>
    </header>
    <div class="detail-body">
      <div class="chips">
        ${a.category ? `<span class="chip">${esc(a.category)}</span>` : ''}
        ${stateChip}
        ${a.updated ? `<span class="chip plain">更新於 ${esc(a.updated)}</span>` : ''}
      </div>
      ${a.description ? `<p class="lead">${esc(a.description)}</p>` : ''}
      <h3>更新紀錄</h3>
      <div class="card">${logHtml}</div>
      <h3>說明</h3>
      ${description}
    </div>
    <footer class="detail-foot">
      ${installedButtons}
      <span class="grow"></span>
      ${primary}
    </footer>`;
  pane.dataset.name = a.name;
  pane.querySelector('.detail-body').scrollTop = scroll;
}

function renderSettings() {
  const d = S.data;
  if (!d) return;
  const u = d.installer;
  const busy = S.busy ? ' disabled' : '';
  const source = d.source
    ? `<b>本機測試：${esc(d.source)}</b>`
    : `<a href="https://github.com/${esc(d.repo)}">github.com/${esc(d.repo)}</a>`;
  const installerButtons = u.hasUpdate
    ? `<button class="btn primary" data-act="selfUpdate"${busy}>${svg('download')}更新到 v${esc(u.latest)}</button>`
    : `<button class="btn" data-act="refresh"${busy}>${svg('refresh')}檢查更新</button>
       <span class="muted-text">${u.latest ? '已是最新版本' : ''}</span>`;

  $('#settingsPane').innerHTML = `
    <div class="settings">
      <h1>設定</h1>
      <section class="card set-card">
        <h3>插件資料夾</h3>
        <div class="path${d.dirOk ? '' : ' bad'}">${svg(d.dirOk ? 'folder' : 'alert')}<span>${esc(d.addonDir)}</span></div>
        ${d.dirOk ? '' : '<p class="warn-text">找不到這個資料夾。請選擇 ArcheRage 的 Addon 資料夾（通常在「文件\\ArcheRage\\Addon」）。</p>'}
        <div class="btn-row">
          <button class="btn" data-act="browseDir">${svg('folder')}瀏覽…</button>
          <button class="btn ghost" data-act="openDir"${d.dirOk ? '' : ' disabled'}>開啟資料夾</button>
          ${d.isDefaultDir ? '' : '<button class="btn ghost" data-act="resetDir">重設為預設位置</button>'}
        </div>
      </section>
      <section class="card set-card">
        <h3>安裝工具</h3>
        <div class="kv"><span>目前版本</span><b>v${esc(u.current)}</b></div>
        <div class="kv"><span>最新版本</span><b>${u.latest ? `v${esc(u.latest)}` : '—'}</b></div>
        <div class="kv"><span>來源</span>${source}</div>
        <div class="btn-row">${installerButtons}</div>
      </section>
      <section class="card set-card">
        <h3>說明</h3>
        <ul class="notes">
          <li>安裝、更新或解除安裝前，會先把插件備份到 <code>Addon\\Backup\\插件名_日期時間</code>。</li>
          <li>更新只覆蓋插件本身的檔案，不會刪除你自己加的檔案。</li>
          <li>安裝或更新後，請在遊戲裡重新載入插件，或重新登入。</li>
          <li>設定存在 <code>%AppData%\\ArcheRageAddonInstaller</code>。</li>
        </ul>
      </section>
    </div>`;
}

function formatBytes(value) {
  const bytes = Math.max(0, Number(value) || 0);
  if (bytes < 1024) return `${Math.round(bytes)} B`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KiB`;
  if (bytes < 1024 ** 3) return `${(bytes / 1024 ** 2).toFixed(1)} MiB`;
  return `${(bytes / 1024 ** 3).toFixed(2)} GiB`;
}

function renderBusy() {
  const b = S.busy;
  $('#busy').hidden = !b;
  if (b) {
    $('#busyText').textContent = b.text;
    $('#busyBar').style.width = `${b.progress}%`;
    const d = b.download;
    $('#busyStats').hidden = !d;
    $('#busyBar').classList.toggle('indeterminate', !!d && d.total <= 0);
    if (d) {
      const size = d.total > 0
        ? `${b.progress}% · ${formatBytes(d.received)} / ${formatBytes(d.total)}`
        : `已下載 ${formatBytes(d.received)} · 總大小未知`;
      $('#busyStats').textContent = `${size} · ${formatBytes(d.bytesPerSecond)}/s`;
    }
  }
}

// ---------- 通知與對話框 ----------

function toast(kind, text) {
  const el = document.createElement('div');
  el.className = `toast ${kind}`;
  el.innerHTML = `${svg(kind === 'ok' ? 'check' : 'alert')}<span></span><button class="toast-x" title="關閉">${svg('x')}</button>`;
  el.querySelector('span').textContent = text;
  el.querySelector('.toast-x').onclick = () => el.remove();
  $('#toasts').append(el);
  setTimeout(() => el.remove(), kind === 'ok' ? 7000 : 12000);
}

let modalResolve = null;

function confirmModal({ title, text, okText = '確定', danger = false }) {
  return new Promise(resolve => {
    modalResolve?.(false);
    modalResolve = resolve;
    $('#modalTitle').textContent = title;
    $('#modalText').textContent = text;
    const ok = $('#modalOk');
    ok.textContent = okText;
    ok.className = danger ? 'btn danger solid' : 'btn primary';
    $('#modal').hidden = false;
    ok.focus();
  });
}

function closeModal(result) {
  $('#modal').hidden = true;
  const resolve = modalResolve;
  modalResolve = null;
  resolve?.(result);
}

$('#modalOk').onclick = () => closeModal(true);
$('#modalCancel').onclick = () => closeModal(false);
$('#modal').addEventListener('mousedown', e => { if (e.target.id === 'modal') closeModal(false); });

// ---------- 操作 ----------

function setView(view) {
  S.view = view;
  render();
}

function select(name) {
  S.selected = name;
  S.showOlder = false;
  if (!(name in S.details)) {
    S.details[name] = undefined;
    post({ type: 'details', name });
  }
  render();
}

const actions = {
  nav: el => setView(el.dataset.view),
  select: el => select(el.dataset.name),
  close: () => { S.selected = null; render(); },
  refresh: () => post({ type: 'refresh' }),
  install: el => post({ type: 'install', names: [el.dataset.name] }),
  updateAll: () => post({ type: 'install', names: addons().filter(a => a.installed && needsUpdate(a)).map(a => a.name) }),
  uninstall: async el => {
    const a = find(el.dataset.name);
    if (!a) return;
    const ok = await confirmModal({
      title: `解除安裝 ${a.title}？`,
      text: '插件會先備份到 Addon\\Backup，再從插件資料夾刪除。',
      okText: '解除安裝',
      danger: true,
    });
    if (ok) post({ type: 'uninstall', name: a.name });
  },
  openDir: el => post({ type: 'openDir', name: el.dataset.name || null }),
  browseDir: () => post({ type: 'browseDir' }),
  resetDir: () => post({ type: 'resetDir' }),
  selfUpdate: () => post({ type: 'selfUpdate' }),
  toggleOlder: () => { S.showOlder = !S.showOlder; renderDetail(); },
};

document.addEventListener('click', e => {
  const link = e.target.closest('a[href]');
  if (link) {
    e.preventDefault();
    const href = link.getAttribute('href');
    if (/^https?:\/\//i.test(href)) post({ type: 'openUrl', url: href });
    return;
  }
  const el = e.target.closest('[data-act]');
  if (!el || el.disabled) return;
  e.stopPropagation();
  actions[el.dataset.act]?.(el);
});

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') {
    if (!$('#modal').hidden) closeModal(false);
    else if (S.selected && S.view !== 'settings') actions.close();
  } else if ((e.key === 'Enter' || e.key === ' ') && e.target.matches?.('[role="button"][data-act]')) {
    e.preventDefault();
    e.target.click();
  } else if (e.ctrlKey && e.key.toLowerCase() === 'f') {
    e.preventDefault();
    if (S.view === 'settings') setView('browse');
    $('#search').focus();
  }
});

$('#search').addEventListener('input', e => { S.search = e.target.value; renderList(); });
$('#category').addEventListener('change', e => { S.category = e.target.value; renderList(); });
$('#sort').addEventListener('change', e => { S.sort = e.target.value; renderList(); });

// ---------- 與 Go 後端溝通 ----------

function onMessage(m) {
  switch (m.type) {
    case 'state': {
      if (m.generation !== S.generation) {
        // 插件清單重新載入過：說明和圖示重新抓
        S.generation = m.generation;
        S.details = {};
        S.brokenIcons.clear();
        if (S.selected) {
          S.details[S.selected] = undefined;
          post({ type: 'details', name: S.selected });
        }
      }
      S.data = m;
      S.busy = m.busy ? { text: m.busy, progress: m.busyProgress, download: m.download } : null;
      if (S.selected && !find(S.selected)) S.selected = null;
      render();
      renderBusy();
      break;
    }
    case 'busy': {
      const wasBusy = !!S.busy;
      S.busy = m.text ? { text: m.text, progress: m.progress, download: m.download } : null;
      renderBusy();
      if (wasBusy !== !!S.busy && S.data) render();
      break;
    }
    case 'details':
      S.details[m.name] = m.html ?? null;
      if (S.selected === m.name) renderDetail();
      break;
    case 'toast':
      toast(m.kind, m.text);
      break;
    case 'confirm':
      confirmModal(m).then(ok => post({ type: 'confirmReply', id: m.id, ok }));
      break;
  }
}

window.runtime?.EventsOn('msg', onMessage);
// 切回視窗時重新讀取本機插件狀態
window.addEventListener('focus', () => post({ type: 'state' }));

document.querySelectorAll('[data-icon]').forEach(el => {
  el.innerHTML = el.dataset.icon === 'logo' ? LOGO : svg(el.dataset.icon);
});
render();
post({ type: 'ready' });

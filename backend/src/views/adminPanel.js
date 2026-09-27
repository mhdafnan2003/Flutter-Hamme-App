// Self-contained admin panel HTML (no external assets).
// - Moderation queue for user reports. Apple Guideline 1.2 requires acting on
//   every report within 24 hours (remove the content + eject the user).
// - Users: complimentary Pro grants and bans.
// - Play settings (app config).
// Served by routes/adminRoutes.js under a strict CSP (inline script/style only,
// same-origin fetch only). Every API call sends the admin key in `x-admin-key`.
// All user-controlled strings are HTML-escaped before rendering, and only
// http(s)/data:image URLs are ever placed in an <img src>.
// NOTE: this whole page is a JS template literal. Inside it, double every
// backslash and never use backticks or a dollar sign followed by a brace.
module.exports = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Hamme Admin · Moderation</title>
<style>
  :root {
    --purple:#7838FE; --purple2:#9E57FF; --bg:#f5f5f7; --line:#e6e6ef; --ink:#1c1c28; --muted:#9a9aae;
    --red:#e5484d; --red-ink:#c62828; --red-bg:#ffe9e9; --amber:#9a5b00; --amber-bg:#fff4e0;
    --green:#1a8f3c; --green-bg:#e8f7ee;
  }
  * { box-sizing: border-box; }
  [hidden] { display:none !important; }
  body { margin:0; font-family: -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; background:var(--bg); color:var(--ink); }
  body.modal-open { overflow:hidden; }
  header { background:linear-gradient(90deg,var(--purple2),var(--purple)); color:#fff; padding:18px 16px 12px; }
  .header-inner { max-width:968px; margin:0 auto; display:flex; justify-content:space-between; align-items:center; gap:14px; flex-wrap:wrap; }
  header h1 { margin:0; font-size:20px; font-weight:800; }
  header p { margin:4px 0 0; opacity:.9; font-size:13px; }
  .nav { max-width:968px; margin:12px auto 0; display:flex; gap:18px; font-size:13px; font-weight:700; }
  .nav a { color:#fff; opacity:.85; text-decoration:none; }
  .nav a:hover { opacity:1; text-decoration:underline; }
  .counters { display:flex; gap:8px; }
  .counter { display:flex; flex-direction:column; align-items:center; justify-content:center; min-width:92px; padding:8px 12px; border-radius:12px; background:rgba(255,255,255,.16); border:1px solid rgba(255,255,255,.35); color:#fff; text-decoration:none; }
  .counter-num { font-size:22px; font-weight:800; line-height:1.1; }
  .counter-label { font-size:11px; font-weight:800; text-transform:uppercase; letter-spacing:.05em; opacity:.92; }
  .counter.alarm { background:var(--red); border-color:#fff; box-shadow:0 0 0 3px rgba(229,72,77,.4); }
  .wrap { max-width:1000px; margin:0 auto; padding:20px 16px 60px; }
  .card { background:#fff; border:1px solid var(--line); border-radius:14px; padding:16px; margin-bottom:16px; }
  .card.primary { border-color:#d8c8ff; box-shadow:0 2px 12px rgba(120,56,254,.08); }
  label { font-size:12px; font-weight:700; color:#6b6b80; display:block; margin-bottom:6px; }
  input, textarea { width:100%; padding:10px 12px; border:1px solid var(--line); border-radius:10px; font-size:14px; font-family:inherit; }
  textarea { resize:vertical; min-height:76px; }
  .row { display:flex; gap:12px; flex-wrap:wrap; align-items:flex-end; }
  .row > div { flex:1; min-width:200px; }
  button { cursor:pointer; border:none; border-radius:10px; padding:10px 14px; font-weight:700; font-size:14px; font-family:inherit; }
  button:disabled { opacity:.5; cursor:not-allowed; }
  button:focus-visible, a:focus-visible, input:focus-visible, textarea:focus-visible, .modal:focus-visible { outline:2px solid var(--purple); outline-offset:2px; }
  .btn-primary { background:var(--purple); color:#fff; }
  .btn-ghost { background:#f0eefe; color:var(--purple); }
  .btn-danger { background:var(--red-bg); color:#d33; }
  .btn-danger-solid { background:var(--red); color:#fff; }
  .btn-outline-danger { background:#fff; color:#d33; border:1px solid #f0b8b8; }
  .btn-sm { padding:7px 11px; font-size:13px; }
  .link-btn { background:none; padding:0; margin-top:4px; border-radius:0; color:var(--purple); font-size:12px; font-weight:700; text-decoration:underline; }
  table { width:100%; border-collapse:collapse; }
  th, td { text-align:left; padding:10px 8px; border-bottom:1px solid var(--line); font-size:14px; vertical-align:middle; }
  th { font-size:11px; text-transform:uppercase; letter-spacing:.04em; color:var(--muted); }
  .table-scroll { overflow-x:auto; }
  .avatar { width:38px; height:38px; border-radius:50%; object-fit:cover; background:#eee; flex:0 0 auto; display:block; }
  .avatar-link { flex:0 0 auto; display:block; border-radius:50%; }
  .avatar-anon { display:flex; align-items:center; justify-content:center; background:#e4e4ee; color:#6b6b80; font-weight:800; font-size:18px; }
  .badge { display:inline-block; padding:3px 10px; border-radius:999px; font-size:12px; font-weight:800; white-space:nowrap; }
  .badge.pro { background:#efeaff; color:var(--purple); }
  .badge.free { background:#eef0f3; color:#7a7a8c; }
  .badge.st-open { background:var(--amber-bg); color:var(--amber); }
  .badge.st-actioned { background:var(--green-bg); color:var(--green); }
  .badge.st-dismissed { background:#eef0f3; color:#6b6b80; }
  .badge.st-reviewed { background:#e9f1ff; color:#2f5fb3; }
  .badge.overdue { background:var(--red); color:#fff; }
  .badge.banned { background:#1c1c28; color:#fff; }
  .badge.anon { background:#eef0f3; color:#3a3a4c; }
  .badge.kind { background:#efeaff; color:var(--purple); }
  .muted { color:var(--muted); font-size:12px; }
  .mono { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; overflow-wrap:anywhere; }
  .toolbar { display:flex; justify-content:space-between; align-items:center; margin-bottom:8px; gap:12px; flex-wrap:wrap; }
  .pager { display:flex; gap:8px; align-items:center; flex-wrap:wrap; }
  #status { font-size:13px; min-height:18px; }
  .status-line { font-size:13px; min-height:18px; margin:6px 0; }
  .err { color:#d33; }
  .ok { color:var(--green); }
  .section-title { font-size:15px; font-weight:800; color:var(--ink); margin:0 0 14px; }
  .settings-row { display:flex; gap:12px; flex-wrap:wrap; align-items:flex-end; }
  .settings-row > div { flex:1; min-width:180px; }
  .number-input { width:100%; padding:10px 12px; border:1px solid var(--line); border-radius:10px; font-size:14px; }
  .hint { font-size:11px; color:var(--muted); margin-top:4px; }
  #settingsStatus { font-size:13px; min-height:18px; margin-top:10px; }

  /* Moderation queue */
  .queue-intro { font-size:13px; color:#6b6b80; max-width:560px; }
  .pills { display:flex; gap:8px; flex-wrap:wrap; }
  .pill { display:inline-flex; align-items:center; padding:6px 12px; border-radius:999px; font-size:13px; font-weight:800; background:#f0eefe; color:var(--purple); }
  .pill.alarm { background:var(--red); color:#fff; }
  .pill.calm { background:var(--green-bg); color:var(--green); }
  .alert { display:flex; align-items:center; justify-content:space-between; gap:10px; flex-wrap:wrap; margin:12px 0 4px; padding:12px 14px; border-radius:12px; background:var(--red); color:#fff; font-size:14px; font-weight:700; }
  .alert button { background:#fff; color:var(--red-ink); }
  .tabs { display:flex; gap:6px; flex-wrap:wrap; margin:14px 0 10px; }
  .tab { background:#f0eefe; color:var(--purple); }
  .tab.active { background:var(--purple); color:#fff; }
  .tab-count { display:inline-block; min-width:20px; margin-left:6px; padding:1px 7px; border-radius:999px; background:rgba(120,56,254,.14); font-size:12px; text-align:center; }
  .tab.active .tab-count { background:rgba(255,255,255,.25); }
  .tab-count:empty { display:none; }
  .stale { display:flex; justify-content:space-between; align-items:center; gap:8px; flex-wrap:wrap; margin:0 0 10px; padding:8px 12px; border-radius:10px; background:#f0eefe; color:var(--purple); font-size:13px; font-weight:700; }
  .report { border:1px solid var(--line); border-radius:12px; padding:14px; margin-bottom:12px; background:#fff; }
  .report.is-overdue { border-color:#f1a9ab; box-shadow:inset 4px 0 0 var(--red); background:#fffafa; }
  .report.is-resolved { background:#fcfcfd; }
  .report.busy { opacity:.7; }
  .reason { font-size:16px; font-weight:800; overflow-wrap:anywhere; }
  .badges { display:flex; flex-wrap:wrap; gap:6px; margin-top:6px; }
  .report-time { font-size:12px; color:#6b6b80; margin-top:8px; }
  .due { font-weight:700; }
  .due.soon { color:var(--amber); }
  .due.overdue { color:var(--red-ink); font-weight:800; }
  .details { margin-top:10px; padding:10px 12px; border-left:3px solid var(--purple2); border-radius:8px; background:#f7f6fb; font-size:14px; white-space:pre-wrap; overflow-wrap:anywhere; }
  .details.none { border-left-color:var(--line); color:var(--muted); font-style:italic; }
  .people { display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-top:12px; }
  .person-box { border:1px solid var(--line); border-radius:10px; padding:10px; min-width:0; }
  .person-box.offender { border-color:#e2d6ff; background:#fbf9ff; }
  .person-label { font-size:11px; font-weight:800; text-transform:uppercase; letter-spacing:.04em; color:var(--muted); margin-bottom:8px; }
  .person { display:flex; align-items:flex-start; gap:10px; min-width:0; }
  .who { min-width:0; overflow-wrap:anywhere; }
  .who-name { font-weight:700; }
  .resolution { margin-top:12px; padding:10px 12px; border-radius:10px; font-size:13px; background:#f3f4f7; }
  .resolution.res-actioned { background:var(--green-bg); }
  .resolution .note { margin-top:6px; white-space:pre-wrap; overflow-wrap:anywhere; }
  .report-actions { display:flex; flex-wrap:wrap; align-items:center; gap:8px; margin-top:12px; }
  .action-msg { font-size:13px; }
  .report-meta { margin-top:10px; font-size:11px; color:var(--muted); }
  .empty { padding:28px 8px; text-align:center; color:var(--muted); font-size:14px; }
  .pager-bottom { justify-content:flex-end; margin-top:4px; }

  /* Users */
  .search-row { margin-bottom:6px; }
  .btn-group { display:flex; flex-wrap:wrap; gap:6px; }
  .btn-group button { white-space:nowrap; }
  .ban-info { margin-top:4px; max-width:240px; overflow-wrap:anywhere; }
  .users-table .person { min-width:200px; align-items:center; }
  tr.is-banned td { background:#fff7f7; }

  /* Confirm dialog */
  .modal-backdrop { position:fixed; top:0; right:0; bottom:0; left:0; z-index:50; display:flex; align-items:center; justify-content:center; padding:16px; background:rgba(20,16,40,.55); }
  .modal { width:100%; max-width:480px; max-height:calc(100vh - 32px); overflow:auto; padding:20px; border-radius:16px; background:#fff; box-shadow:0 20px 60px rgba(0,0,0,.25); }
  .modal h2 { margin:0 0 10px; font-size:18px; overflow-wrap:anywhere; }
  .modal-body p { margin:0 0 10px; font-size:14px; line-height:1.45; color:#3a3a4c; overflow-wrap:anywhere; }
  .modal-body p.modal-warning { padding:8px 10px; border-radius:8px; background:var(--amber-bg); color:var(--amber); font-weight:700; }
  #modalError { font-size:13px; min-height:18px; margin-top:8px; }
  .modal-actions { display:flex; justify-content:flex-end; gap:8px; flex-wrap:wrap; margin-top:10px; }

  @media (max-width: 640px) {
    header { padding:14px 12px 10px; }
    header h1 { font-size:18px; }
    .counters { width:100%; }
    .counter { flex:1; min-width:0; }
    .wrap { padding:12px 10px 48px; }
    .card { padding:14px 12px; border-radius:12px; }
    input, textarea { font-size:16px; }
    .toolbar .pager { width:100%; justify-content:space-between; }
    .tab { padding:8px 11px; font-size:13px; }
    .report { padding:12px; }
    .people { grid-template-columns:1fr; }
    .report-actions button { flex:1 1 auto; }
    .action-msg { flex-basis:100%; }
    .users-table thead { display:none; }
    .users-table, .users-table tbody, .users-table tr, .users-table td { display:block; width:100%; }
    .users-table tr { border:1px solid var(--line); border-radius:12px; padding:10px 12px; margin-bottom:10px; }
    .users-table tr.is-banned { border-color:#f0b8b8; background:#fff7f7; }
    .users-table td, tr.is-banned td { border:none; padding:6px 0; background:none; }
    .users-table td[data-label] { display:flex; justify-content:space-between; align-items:flex-start; gap:12px; text-align:right; }
    .users-table td[data-label]::before { content:attr(data-label); flex:0 0 auto; padding-top:3px; font-size:11px; font-weight:800; text-transform:uppercase; letter-spacing:.04em; color:var(--muted); text-align:left; }
    .users-table .person { min-width:0; }
    .users-table .btn-group button { flex:1 1 auto; }
    .ban-info { margin-left:auto; }
    .modal-backdrop { align-items:flex-end; padding:0; }
    .modal { max-width:none; max-height:92vh; border-radius:16px 16px 0 0; padding:18px 16px 22px; }
    .modal-actions button { flex:1 1 auto; }
  }
</style>
</head>
<body>
<header>
  <div class="header-inner">
    <div>
      <h1>Hamme Admin</h1>
      <p>Moderation queue, users and plans. Every report must be acted on within 24 hours.</p>
    </div>
    <div class="counters">
      <a class="counter" id="hdrOpen" href="#reports" title="Open reports"><span class="counter-num" id="openCount">&ndash;</span><span class="counter-label">Open</span></a>
      <a class="counter" id="hdrOverdue" href="#reports" title="Open reports older than 24 hours"><span class="counter-num" id="overdueCount">&ndash;</span><span class="counter-label">Overdue &gt;24h</span></a>
    </div>
  </div>
  <nav class="nav" aria-label="Sections"><a href="#reports">Reports</a><a href="#users">Users</a><a href="#settings">Settings</a></nav>
</header>
<div class="wrap">
  <div class="card">
    <div class="row">
      <div>
        <label for="adminKey">Admin key</label>
        <input id="adminKey" type="password" placeholder="Enter ADMIN_API_KEY" />
      </div>
      <div style="flex:0 0 auto;">
        <button type="button" class="btn-primary" id="saveKey">Save &amp; Load</button>
      </div>
    </div>
    <div id="status" style="margin-top:10px;" aria-live="polite"></div>
  </div>

  <section class="card primary" id="reports" aria-labelledby="reportsTitle">
    <div class="toolbar">
      <div>
        <div class="section-title" id="reportsTitle" style="margin-bottom:3px;">🚩 Moderation queue</div>
        <div class="queue-intro">Act on every report within 24 hours: remove content that breaks the rules and ban the user responsible.</div>
      </div>
      <div class="pills">
        <span class="pill" id="qOpen">&ndash; open</span>
        <span class="pill" id="qOverdue">&ndash; overdue</span>
      </div>
    </div>
    <div class="alert" id="overdueAlert" role="alert" hidden>
      <span id="overdueAlertText"></span>
      <button type="button" class="btn-sm" id="overdueShow">Show open reports</button>
    </div>
    <div class="tabs" id="reportTabs" role="tablist" aria-label="Report status">
      <button type="button" class="tab active" role="tab" aria-selected="true" data-status="open">Open<span class="tab-count" id="tabOpenCount"></span></button>
      <button type="button" class="tab" role="tab" aria-selected="false" data-status="actioned">Actioned</button>
      <button type="button" class="tab" role="tab" aria-selected="false" data-status="dismissed">Dismissed</button>
      <button type="button" class="tab" role="tab" aria-selected="false" data-status="all">All</button>
    </div>
    <div class="toolbar">
      <div>
        <div class="muted" id="reportSummary">No reports loaded.</div>
        <div class="muted" id="countersUpdated"></div>
      </div>
      <div class="pager">
        <button type="button" class="btn-ghost" id="reportRefresh">Refresh</button>
        <button type="button" class="btn-ghost report-prev" id="reportPrev">&lsaquo; Prev</button>
        <span class="muted report-page-info" id="reportPageInfo">&ndash;</span>
        <button type="button" class="btn-ghost report-next" id="reportNext">Next &rsaquo;</button>
      </div>
    </div>
    <div id="reportStatus" class="status-line" aria-live="polite"></div>
    <div class="stale" id="reportStale" hidden>
      <span>The queue has changed since this list was loaded.</span>
      <button type="button" class="btn-primary btn-sm" id="reportStaleRefresh">Refresh list</button>
    </div>
    <div id="reportList"><div class="empty">Enter your admin key and click Save &amp; Load.</div></div>
    <div class="pager pager-bottom">
      <button type="button" class="btn-ghost report-prev">&lsaquo; Prev</button>
      <span class="muted report-page-info">&ndash;</span>
      <button type="button" class="btn-ghost report-next">Next &rsaquo;</button>
    </div>
  </section>

  <section class="card" id="users" aria-labelledby="usersTitle">
    <div class="toolbar">
      <div>
        <div class="section-title" id="usersTitle" style="margin-bottom:3px;">👥 Users</div>
        <div class="muted" id="summary">No data loaded.</div>
      </div>
      <div class="pager">
        <button type="button" class="btn-ghost" id="prev">&lsaquo; Prev</button>
        <span class="muted" id="pageInfo">&ndash;</span>
        <button type="button" class="btn-ghost" id="next">Next &rsaquo;</button>
      </div>
    </div>
    <div class="search-row">
      <label for="search">Search (name, username, email, code)</label>
      <input id="search" type="text" placeholder="Type to search…" />
    </div>
    <div id="userStatus" class="status-line" aria-live="polite"></div>
    <div class="table-scroll">
      <table class="users-table">
        <thead>
          <tr><th>User</th><th>Share code</th><th>Plan</th><th>Status</th><th>Actions</th></tr>
        </thead>
        <tbody id="rows"><tr><td colspan="5" class="muted">Enter your admin key and click “Save &amp; Load”.</td></tr></tbody>
      </table>
    </div>
  </section>

  <section class="card" id="settings">
    <div class="section-title">⚙️ Play Settings</div>
    <div class="settings-row">
      <div>
        <label for="cardLimit">Free card limit per session</label>
        <input id="cardLimit" class="number-input" type="number" min="1" max="1000" placeholder="10" />
        <div class="hint">How many cards free users can view before cooldown.</div>
      </div>
      <div>
        <label for="cooldownMinutes">Cooldown duration (minutes)</label>
        <input id="cooldownMinutes" class="number-input" type="number" min="1" max="1440" placeholder="5" />
        <div class="hint">How many minutes free users wait before seeing more cards.</div>
      </div>
      <div style="flex:0 0 auto;">
        <button type="button" class="btn-primary" id="saveSettings">Save Settings</button>
      </div>
    </div>
    <div id="settingsStatus"></div>
  </section>
</div>

<div class="modal-backdrop" id="modal" hidden>
  <div class="modal" id="modalDialog" role="dialog" aria-modal="true" aria-labelledby="modalTitle" aria-describedby="modalBody" tabindex="-1">
    <h2 id="modalTitle"></h2>
    <div class="modal-body" id="modalBody"></div>
    <div id="modalField" hidden>
      <label for="modalInput" id="modalInputLabel"></label>
      <textarea id="modalInput" rows="3" maxlength="500"></textarea>
    </div>
    <div id="modalError" class="err" role="alert"></div>
    <div class="modal-actions">
      <button type="button" class="btn-ghost" id="modalCancel">Cancel</button>
      <button type="button" class="btn-danger-solid" id="modalConfirm">Confirm</button>
    </div>
  </div>
</div>

<script>
  var API_BASE = location.pathname.replace(/\\/$/, '');
  var HOUR_MS = 60 * 60 * 1000;
  var DAY_MS = 24 * HOUR_MS;
  var COUNTER_POLL_MS = 60 * 1000;
  var state = { page: 1, limit: 25, search: '', pages: 1, seq: 0, byId: Object.create(null) };
  var reportState = { page: 1, limit: 25, pages: 1, status: 'open', seq: 0, loading: false, byId: Object.create(null), listOpenCount: null };
  var counterState = { busy: false, lastAt: 0 };
  var memoryKey = '';
  var $ = function (id) { return document.getElementById(id); };
  var each = function (list, fn) { Array.prototype.forEach.call(list, fn); };

  var REASON_LABELS = {
    harassment: 'Bullying or harassment',
    sexual: 'Nudity or sexual content',
    hate: 'Hate speech or symbols',
    violence: 'Violence or threats',
    self_harm: 'Self-harm or suicide',
    impersonation: 'Fake account or impersonation',
    underage: 'User may be under 13',
    spam: 'Spam or scam',
    other: 'Something else'
  };
  var TYPE_LABELS = { friend: 'Friend', crush: 'Crush', frenemy: 'Frenemy' };
  var STATUS_LABELS = { open: 'Open', actioned: 'Actioned', dismissed: 'Dismissed', reviewed: 'Reviewed' };
  var STATUS_CLASSES = { open: 'st-open', actioned: 'st-actioned', dismissed: 'st-dismissed', reviewed: 'st-reviewed' };
  // Admin actions, plus the side-effect resolutions set when a ban or account
  // deletion closes other open reports automatically.
  var RESOLUTION_LABELS = {
    remove_content: 'Content removed',
    remove_and_ban: 'Content removed and offender banned',
    dismiss: 'Dismissed',
    dismissed: 'Dismissed',
    user_banned: 'Closed automatically: user banned',
    session_banned: 'Closed automatically: anonymous voter banned',
    account_deleted: 'Closed automatically: account deleted'
  };

  function getKey() {
    try { return localStorage.getItem('hamme_admin_key') || memoryKey; } catch (e) { return memoryKey; }
  }
  function setKey(v) {
    memoryKey = v;
    try { localStorage.setItem('hamme_admin_key', v); } catch (e) {}
  }

  function setStatus(msg, kind) {
    var el = $('status');
    el.textContent = msg || '';
    el.className = kind || '';
  }
  function setLine(id, msg, kind) {
    var el = $(id);
    el.textContent = msg || '';
    el.className = 'status-line' + (kind ? ' ' + kind : '');
  }
  function setUserStatus(msg, kind) { setLine('userStatus', msg, kind); }
  function setReportStatus(msg, kind) { setLine('reportStatus', msg, kind); }

  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c];
    });
  }

  function lookup(map, key, fallback) {
    return Object.prototype.hasOwnProperty.call(map, key) ? map[key] : fallback;
  }

  function humanize(s) {
    var t = String(s == null ? '' : s).replace(/_/g, ' ').trim();
    return t ? t.charAt(0).toUpperCase() + t.slice(1) : '';
  }

  // Only http(s) and inline data:image URLs may be used as an image source.
  function safeImgSrc(url) {
    if (typeof url !== 'string') return '';
    var u = url.trim();
    var lower = u.toLowerCase();
    if (lower.indexOf('https://') === 0 || lower.indexOf('http://') === 0 || lower.indexOf('data:image/') === 0) return u;
    return '';
  }

  function avatarHtml(url, linkToFull) {
    var src = safeImgSrc(url);
    if (!src) return '<div class="avatar"></div>';
    var img = '<img class="avatar" alt="" loading="lazy" referrerpolicy="no-referrer" src="' + escapeHtml(src) + '"/>';
    if (linkToFull && src.toLowerCase().indexOf('http') === 0) {
      return '<a class="avatar-link" href="' + escapeHtml(src) + '" target="_blank" rel="noopener noreferrer" title="Open full-size photo">' + img + '</a>';
    }
    return img;
  }

  // Swap broken avatars for the grey placeholder (replaces inline onerror handlers).
  document.addEventListener('error', function (e) {
    var t = e.target;
    if (!t || t.tagName !== 'IMG' || !t.classList.contains('avatar')) return;
    var placeholder = document.createElement('div');
    placeholder.className = 'avatar';
    if (t.replaceWith) t.replaceWith(placeholder); else t.style.visibility = 'hidden';
  }, true);

  async function api(path, options) {
    options = options || {};
    options.headers = Object.assign({ 'x-admin-key': getKey(), 'Content-Type': 'application/json' }, options.headers || {});
    var res;
    try {
      res = await fetch(API_BASE + path, options);
    } catch (e) {
      throw new Error('Network error. Check your connection and try again.');
    }
    var data = null;
    try { data = await res.json(); } catch (e) {}
    if (!res.ok) {
      // Only the user-facing message is shown; the error details are never relied on.
      var err = new Error((data && data.message) || ('Request failed (' + res.status + ')'));
      err.status = res.status;
      throw err;
    }
    return data || {};
  }

  // Surface a bad/missing admin key next to the key input.
  function noteAuthError(e) {
    if (e && (e.status === 401 || e.status === 503)) setStatus(e.message, 'err');
  }

  // ── Time helpers ──────────────────────────────────────────────────────────
  function toTime(v) {
    if (v == null || v === '') return null;
    var t = new Date(v).getTime();
    return isNaN(t) ? null : t;
  }
  function fmtDate(v) {
    var t = toTime(v);
    return t == null ? '' : new Date(t).toLocaleString();
  }
  function fmtDuration(ms) {
    var mins = Math.max(0, Math.floor(ms / 60000));
    if (mins < 60) return mins + 'm';
    var hours = Math.floor(mins / 60);
    if (hours < 24) return hours + 'h ' + (mins % 60) + 'm';
    var days = Math.floor(hours / 24);
    return days + 'd ' + (hours % 24) + 'h';
  }
  function timeAgo(v) {
    var t = toTime(v);
    if (t == null) return '';
    var secs = Math.max(0, Math.floor((Date.now() - t) / 1000));
    if (secs < 60) return 'just now';
    var mins = Math.floor(secs / 60);
    if (mins < 60) return mins + 'm ago';
    var hours = Math.floor(mins / 60);
    if (hours < 24) return hours + 'h ago';
    var days = Math.floor(hours / 24);
    if (days < 60) return days + 'd ago';
    return Math.floor(days / 30) + 'mo ago';
  }
  // Time left before an open report breaches the 24h deadline.
  function dueInfo(createdAt, serverOverdue) {
    var t = toTime(createdAt);
    var left = t == null ? null : t + DAY_MS - Date.now();
    if (left != null && left <= 0) return { text: 'Overdue by ' + fmtDuration(-left), cls: 'due overdue', overdue: true };
    if (serverOverdue) return { text: 'Overdue', cls: 'due overdue', overdue: true };
    if (left == null) return { text: '', cls: 'due', overdue: false };
    return { text: fmtDuration(left) + ' left to act', cls: left < 4 * HOUR_MS ? 'due soon' : 'due', overdue: false };
  }

  // ── Users ─────────────────────────────────────────────────────────────────
  function whoLabel(p) {
    p = p || {};
    if (p.username) return '@' + p.username;
    return p.name || p.email || 'this user';
  }

  function userCellHtml(u) {
    var lines = '';
    if (u.username) lines += '<div class="muted">@' + escapeHtml(u.username) + '</div>';
    if (u.email) lines += '<div class="muted">' + escapeHtml(u.email) + '</div>';
    return '<div class="person">' + avatarHtml(u.avatarUrl, false) +
      '<div class="who"><div class="who-name">' + escapeHtml(u.name || 'Unnamed user') + '</div>' + lines + '</div></div>';
  }

  function render(data) {
    var tbody = $('rows');
    var users = Array.isArray(data.users) ? data.users : [];
    state.pages = Math.max(1, Number(data.pages) || 1);
    state.byId = Object.create(null);
    $('summary').textContent = (Number(data.total) || 0) + ' user(s) total';
    $('pageInfo').textContent = 'Page ' + (Number(data.page) || state.page) + ' / ' + state.pages;
    $('prev').disabled = state.page <= 1;
    $('next').disabled = state.page >= state.pages;
    if (!users.length) {
      tbody.innerHTML = '<tr><td colspan="5" class="muted">No users found.</td></tr>';
      return;
    }
    tbody.innerHTML = users.map(function (u) {
      u = u || {};
      var id = String(u.id == null ? '' : u.id);
      state.byId[id] = u;
      var idAttr = escapeHtml(id);
      var adminPro = !!u.adminPro;
      var storePro = !!u.storeProActive;
      var source = storePro && adminPro ? 'PLAY + ADMIN' : storePro ? 'PLAY' : adminPro ? 'ADMIN' : 'LEGACY';
      var badge = u.isPro ? '<span class="badge pro">PRO · ' + source + '</span>' : '<span class="badge free">FREE</span>';
      var planBtn = adminPro
        ? '<button type="button" class="btn-danger btn-sm" data-id="' + idAttr + '" data-pro="false">Remove admin grant</button>'
        : '<button type="button" class="btn-primary btn-sm" data-id="' + idAttr + '" data-pro="true">Grant Pro</button>';
      var banBtn = u.isBanned
        ? '<button type="button" class="btn-ghost btn-sm" data-id="' + idAttr + '" data-ban="unban">Unban</button>'
        : '<button type="button" class="btn-outline-danger btn-sm" data-id="' + idAttr + '" data-ban="ban">Ban</button>';
      var statusHtml = u.isBanned
        ? '<span class="badge banned">BANNED</span>' +
          (u.banReason ? '<div class="muted ban-info">Reason: ' + escapeHtml(u.banReason) + '</div>' : '') +
          (u.bannedAt ? '<div class="muted ban-info">Since ' + escapeHtml(fmtDate(u.bannedAt)) + '</div>' : '')
        : '<span class="muted">Active</span>';
      return '<tr' + (u.isBanned ? ' class="is-banned"' : '') + '>' +
        '<td>' + userCellHtml(u) + '</td>' +
        '<td data-label="Share code"><span class="muted">' + escapeHtml(u.shareCode || '') + '</span></td>' +
        '<td data-label="Plan">' + badge + '</td>' +
        '<td data-label="Status"><div>' + statusHtml + '</div></td>' +
        '<td><div class="btn-group">' + planBtn + banBtn + '</div></td>' +
      '</tr>';
    }).join('');
  }

  async function load() {
    if (!getKey()) { setStatus('Enter your admin key first.', 'err'); return; }
    var seq = ++state.seq;
    setUserStatus('Loading…');
    try {
      var q = '/users?page=' + state.page + '&limit=' + state.limit + '&search=' + encodeURIComponent(state.search);
      var data = await api(q);
      if (seq !== state.seq) return;
      render(data);
      setUserStatus('Loaded.', 'ok');
    } catch (e) {
      if (seq !== state.seq) return;
      setUserStatus(e.message, 'err');
      noteAuthError(e);
    }
  }

  async function setPlan(id, isPro) {
    setUserStatus('Updating…');
    try {
      await api('/users/' + encodeURIComponent(id) + '/plan', { method: 'PATCH', body: JSON.stringify({ isPro: isPro }) });
      setUserStatus(isPro ? 'Admin Pro grant added.' : 'Admin Pro grant removed.', 'ok');
      load();
    } catch (e) {
      setUserStatus(e.message, 'err');
    }
  }

  function openBan(u) {
    var who = whoLabel(u);
    openModal({
      title: 'Ban ' + who + '?',
      body: [
        'This permanently suspends the account. ' + who + ' is signed out on every device, every vote they sent and all of their matches are deleted, their profile photo is removed and their public poll page goes offline.',
        'They cannot sign in, or register again from the same device, until you unban them.'
      ],
      inputLabel: 'Reason (optional, only admins see this)',
      inputPlaceholder: 'e.g. Harassment in votes, reported by several users',
      confirmLabel: 'Ban user',
      danger: true,
      onConfirm: function (reason) {
        return api('/users/' + encodeURIComponent(u.id) + '/ban', { method: 'POST', body: JSON.stringify(reason ? { reason: reason } : {}) });
      },
      onSuccess: function () {
        setUserStatus(who + ' has been banned.', 'ok');
        load();
        loadReports();
      }
    });
  }

  function openUnban(u) {
    var who = whoLabel(u);
    openModal({
      title: 'Unban ' + who + '?',
      body: [
        'They will be able to sign in and use Hamme again.',
        'Votes, matches and the profile photo deleted by the ban are not restored.'
      ],
      confirmLabel: 'Unban user',
      danger: false,
      onConfirm: function () {
        return api('/users/' + encodeURIComponent(u.id) + '/unban', { method: 'POST', body: '{}' });
      },
      onSuccess: function () {
        setUserStatus(who + ' has been unbanned.', 'ok');
        load();
        loadReports();
      }
    });
  }

  function findUser(term) {
    clearTimeout(searchTimer); // a pending keystroke search must not override this
    $('search').value = term;
    state.search = term;
    state.page = 1;
    load();
    $('users').scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  // ── Reports / moderation queue ────────────────────────────────────────────
  function targetTypeOf(r) {
    if (r.targetType === 'profile' || r.targetType === 'interaction') return r.targetType;
    return r.interactionId ? 'interaction' : 'profile';
  }

  function reasonLabel(reason) {
    if (!reason) return 'No reason given';
    return lookup(REASON_LABELS, reason, humanize(reason));
  }

  function personHtml(person, id, extra) {
    person = person || {};
    var lines = '';
    if (person.username) lines += '<div class="muted">@' + escapeHtml(person.username) + '</div>';
    if (person.email) lines += '<div class="muted">' + escapeHtml(person.email) + '</div>';
    if (person.shareCode) lines += '<div class="muted">Share code: ' + escapeHtml(person.shareCode) + '</div>';
    if (id) lines += '<div class="muted mono">ID: ' + escapeHtml(id) + '</div>';
    return '<div class="person">' + avatarHtml(person.avatarUrl, true) +
      '<div class="who"><div class="who-name">' + escapeHtml(person.name || 'Unknown user') + '</div>' + lines + (extra || '') + '</div></div>';
  }

  function anonymousVoterHtml(sessionId) {
    return '<div class="person"><div class="avatar avatar-anon" aria-hidden="true">?</div>' +
      '<div class="who"><div class="who-name">Anonymous web voter</div>' +
      '<div class="muted">Not signed in</div>' +
      '<div class="muted mono">Session: ' + escapeHtml(sessionId || 'not recorded') + '</div></div></div>';
  }

  function reportCardHtml(r) {
    var id = String(r.id == null ? '' : r.id);
    var status = String(r.status || 'open');
    var isOpen = status === 'open';
    var kind = targetTypeOf(r);
    var created = r.createdAt == null ? '' : String(r.createdAt);
    var due = isOpen ? dueInfo(created, !!r.overdue) : null;
    var overdue = !!(due && due.overdue);

    var badges = '<span class="badge ' + lookup(STATUS_CLASSES, status, 'free') + '">' + escapeHtml(status.toUpperCase()) + '</span>';
    if (overdue) badges += '<span class="badge overdue">OVERDUE</span>';
    var kindText = kind === 'profile'
      ? 'Profile'
      : 'Vote' + (r.interactionType ? ' · ' + lookup(TYPE_LABELS, r.interactionType, humanize(r.interactionType)) : '');
    badges += '<span class="badge kind">' + escapeHtml(kindText) + '</span>';
    if (r.anonymous) badges += '<span class="badge anon">Anonymous voter</span>';
    if (r.reportedUserBanned) badges += '<span class="badge banned">Banned</span>';

    var time = '<div class="report-time">Reported <span title="' + escapeHtml(created) + '">' + escapeHtml(fmtDate(created)) + '</span>' +
      ' · <span data-age="' + escapeHtml(created) + '">' + escapeHtml(timeAgo(created)) + '</span>' +
      (due && due.text
        ? ' · <span class="' + due.cls + '" data-due="' + escapeHtml(created) + '" data-over="' + (r.overdue ? '1' : '0') + '">' + escapeHtml(due.text) + '</span>'
        : '') +
      '</div>';

    var details = r.details
      ? '<div class="details">' + escapeHtml(r.details) + '</div>'
      : '<div class="details none">No details provided by the reporter.</div>';

    var reportedHtml;
    if (r.reportedUserId || r.reportedUser) {
      var snap = r.reportedUser || {};
      var extra = '';
      if (r.anonymous && r.anonymousSessionId) extra += '<div class="muted mono">Session: ' + escapeHtml(r.anonymousSessionId) + '</div>';
      var findTerm = snap.shareCode || snap.email || snap.username || '';
      if (r.reportedUserId && findTerm) extra += '<button type="button" class="link-btn" data-find="' + escapeHtml(findTerm) + '">Find in Users</button>';
      reportedHtml = personHtml(snap, r.reportedUserId, extra);
    } else {
      reportedHtml = anonymousVoterHtml(r.anonymousSessionId);
    }
    var people = '<div class="people">' +
      '<div class="person-box offender"><div class="person-label">' + (kind === 'profile' ? 'Reported profile' : 'Reported voter') + '</div>' + reportedHtml + '</div>' +
      '<div class="person-box"><div class="person-label">Reported by</div>' + personHtml(r.reporter, r.reporterId, '') + '</div>' +
    '</div>';

    var resolution = '';
    if (!isOpen) {
      var resolvedT = toTime(r.resolvedAt);
      var createdT = toTime(created);
      var statusText = lookup(STATUS_LABELS, status, humanize(status));
      var resolutionText = r.resolution ? lookup(RESOLUTION_LABELS, r.resolution, humanize(r.resolution)) : '';
      if (resolutionText.toLowerCase() === statusText.toLowerCase()) resolutionText = '';
      resolution = '<div class="resolution' + (status === 'actioned' ? ' res-actioned' : '') + '">' +
        '<div><strong>' + escapeHtml(statusText) + '</strong>' +
        (resolutionText ? ' · ' + escapeHtml(resolutionText) : '') + '</div>' +
        (resolvedT != null
          ? '<div class="muted">Resolved ' + escapeHtml(fmtDate(r.resolvedAt)) +
            (createdT != null ? ' · handled in ' + escapeHtml(fmtDuration(resolvedT - createdT)) : '') + '</div>'
          : '') +
        (r.adminNote ? '<div class="note"><span class="muted">Admin note:</span> ' + escapeHtml(r.adminNote) + '</div>' : '') +
      '</div>';
    }

    var actions = '';
    if (isOpen && id) {
      var idAttr = escapeHtml(id);
      actions = '<div class="report-actions">' +
        '<button type="button" class="btn-danger" data-action="remove_content" data-id="' + idAttr + '">Remove content</button>' +
        '<button type="button" class="btn-danger-solid" data-action="remove_and_ban" data-id="' + idAttr + '">Remove &amp; ban</button>' +
        '<button type="button" class="btn-ghost" data-action="dismiss" data-id="' + idAttr + '">Dismiss</button>' +
        '<span class="action-msg" aria-live="polite"></span>' +
      '</div>';
    }

    var meta = '<div class="report-meta mono">Report ' + escapeHtml(id) + (r.interactionId ? ' · Vote ' + escapeHtml(r.interactionId) : '') + '</div>';

    return '<article class="report' + (overdue ? ' is-overdue' : '') + (isOpen ? '' : ' is-resolved') + '" data-id="' + escapeHtml(id) + '">' +
      '<div class="reason">' + escapeHtml(reasonLabel(r.reason)) + '</div>' +
      '<div class="badges">' + badges + '</div>' +
      time + details + people + resolution + actions + meta +
    '</article>';
  }

  function updateReportPager() {
    each(document.querySelectorAll('.report-page-info'), function (el) {
      el.textContent = 'Page ' + reportState.page + ' / ' + reportState.pages;
    });
    each(document.querySelectorAll('.report-prev'), function (b) { b.disabled = reportState.page <= 1; });
    each(document.querySelectorAll('.report-next'), function (b) { b.disabled = reportState.page >= reportState.pages; });
  }

  function renderReports(data) {
    var list = $('reportList');
    var reports = Array.isArray(data.reports) ? data.reports : [];
    var status = reportState.status;
    var statusWord = lookup(STATUS_LABELS, status, status).toLowerCase();
    reportState.pages = Math.max(1, Number(data.pages) || 1);
    reportState.page = Math.max(1, Number(data.page) || reportState.page);
    reportState.byId = Object.create(null);
    reports.forEach(function (r) { if (r && r.id != null) reportState.byId[String(r.id)] = r; });
    var total = Number(data.total) || 0;
    $('reportSummary').textContent = status === 'all' ? total + ' report(s) total' : total + ' ' + statusWord + ' report(s)';
    updateReportPager();
    if (!reports.length) {
      var empty = status === 'open' ? 'No open reports. The queue is clear. 🎉'
        : status === 'all' ? 'No reports yet.' : 'No ' + statusWord + ' reports.';
      list.innerHTML = '<div class="empty">' + escapeHtml(empty) + '</div>';
      return;
    }
    list.innerHTML = reports.map(function (r) { return reportCardHtml(r || {}); }).join('');
  }

  function numOrNull(v) {
    if (v == null || v === '') return null;
    var n = Number(v);
    return isFinite(n) ? n : null;
  }

  function updateCounters(data) {
    var open = numOrNull(data && data.openCount);
    if (open == null) return; // Backend did not send counters.
    var overdue = numOrNull(data.overdueCount) || 0;
    $('openCount').textContent = String(open);
    $('overdueCount').textContent = String(overdue);
    $('hdrOverdue').classList.toggle('alarm', overdue > 0);
    $('qOpen').textContent = open + ' open';
    $('qOverdue').textContent = overdue + ' overdue';
    $('qOverdue').className = 'pill ' + (overdue > 0 ? 'alarm' : 'calm');
    $('tabOpenCount').textContent = open > 0 ? String(open) : '';
    $('overdueAlert').hidden = overdue === 0;
    $('overdueAlertText').textContent = '⚠️ ' + overdue + (overdue === 1 ? ' report is' : ' reports are') +
      ' past the 24-hour deadline. Apple requires action within 24 hours. Handle these first.';
    $('overdueShow').hidden = reportState.status === 'open';
    document.title = (overdue > 0 ? '(' + overdue + ' overdue) ' : open > 0 ? '(' + open + ') ' : '') + 'Hamme Admin · Moderation';
    counterState.lastAt = Date.now();
    $('countersUpdated').textContent = 'Counts updated ' +
      new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) + ' · auto-refresh every minute';
  }

  async function loadReports() {
    if (!getKey()) return;
    var seq = ++reportState.seq;
    reportState.loading = true;
    $('reportSummary').textContent = 'Loading reports…';
    try {
      var q = '/reports?status=' + encodeURIComponent(reportState.status) + '&page=' + reportState.page + '&limit=' + reportState.limit;
      var data = await api(q);
      if (seq !== reportState.seq) return;
      var pages = Math.max(1, Number(data.pages) || 1);
      var reports = Array.isArray(data.reports) ? data.reports : [];
      if (!reports.length && reportState.page > pages) {
        // The last page emptied (e.g. after an action): step back.
        reportState.page = pages;
        return loadReports();
      }
      renderReports(data);
      updateCounters(data);
      reportState.listOpenCount = numOrNull(data.openCount);
      $('reportStale').hidden = true;
    } catch (e) {
      if (seq !== reportState.seq) return;
      $('reportSummary').textContent = e.message;
      $('reportList').innerHTML = '<div class="empty err">Could not load reports.</div>';
      noteAuthError(e);
    } finally {
      if (seq === reportState.seq) reportState.loading = false;
    }
  }

  // Lightweight poll: only the counters (limit=1), never re-renders the list.
  async function refreshCounters() {
    if (!getKey() || counterState.busy || document.hidden) return;
    counterState.busy = true;
    try {
      var data = await api('/reports?status=open&page=1&limit=1');
      updateCounters(data);
      var open = numOrNull(data.openCount);
      if (open != null && reportState.listOpenCount != null && open !== reportState.listOpenCount &&
          !reportState.loading && (reportState.status === 'open' || reportState.status === 'all')) {
        $('reportStale').hidden = false;
      }
    } catch (e) {
      noteAuthError(e);
    } finally {
      counterState.busy = false;
    }
  }

  function tickAges() {
    each(document.querySelectorAll('#reportList [data-age]'), function (el) {
      el.textContent = timeAgo(el.getAttribute('data-age'));
    });
    each(document.querySelectorAll('#reportList [data-due]'), function (el) {
      var info = dueInfo(el.getAttribute('data-due'), el.getAttribute('data-over') === '1');
      el.textContent = info.text;
      el.className = info.cls;
    });
  }

  function setReportFilter(status) {
    reportState.status = status;
    reportState.page = 1;
    each(document.querySelectorAll('#reportTabs [data-status]'), function (tab) {
      var on = tab.getAttribute('data-status') === status;
      tab.classList.toggle('active', on);
      tab.setAttribute('aria-selected', on ? 'true' : 'false');
    });
    $('overdueShow').hidden = status === 'open';
    setReportStatus('');
    loadReports();
  }

  function findCard(id) {
    var cards = document.querySelectorAll('#reportList .report');
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].getAttribute('data-id') === String(id)) return cards[i];
    }
    return null;
  }

  function setCardBusy(id, busy, msg, kind) {
    var card = findCard(id);
    if (!card) return;
    each(card.querySelectorAll('.report-actions button'), function (b) { b.disabled = busy; });
    card.classList.toggle('busy', busy);
    var m = card.querySelector('.action-msg');
    if (m) {
      m.textContent = msg || '';
      m.className = 'action-msg' + (kind ? ' ' + kind : '');
    }
  }

  // Confirmation copy: spell out exactly what each action does.
  function describeAction(r, action) {
    var kind = targetTypeOf(r);
    var hasAccount = !!r.reportedUserId;
    var who = hasAccount ? whoLabel(r.reportedUser) : 'the anonymous voter';
    var vote = r.interactionType ? lookup(TYPE_LABELS, r.interactionType, humanize(r.interactionType)) + ' vote' : 'vote';
    if (action === 'dismiss') {
      return {
        title: 'Dismiss this report?',
        body: [
          'Nothing is removed and nobody is banned. The report moves to Dismissed.',
          'Only dismiss a report when the content does not break the community guidelines.'
        ],
        confirmLabel: 'Dismiss report',
        danger: false,
        success: 'Report dismissed.'
      };
    }
    if (action === 'remove_content') {
      if (kind === 'profile') {
        return {
          title: 'Remove profile photo?',
          body: [
            'Deletes the profile photo of ' + who + '. The account stays active and is not banned.',
            'The report is marked as actioned.'
          ],
          confirmLabel: 'Remove photo',
          danger: true,
          success: 'Profile photo removed. Report actioned.'
        };
      }
      return {
        title: 'Remove this vote?',
        body: [
          "Permanently deletes this " + vote + " from the recipient's feed. " + (hasAccount ? who + ' is not banned.' : 'The anonymous voter is not banned.'),
          'The report is marked as actioned.'
        ],
        confirmLabel: 'Remove vote',
        danger: true,
        success: 'Vote removed. Report actioned.'
      };
    }
    if (action !== 'remove_and_ban') return null;
    if (!hasAccount) {
      var sid = r.anonymousSessionId;
      return {
        title: 'Remove vote and ban anonymous voter?',
        body: [
          "Deletes this " + vote + " and bans this anonymous voter's browser session" + (sid ? ' (' + sid + ')' : '') + '.',
          'Every anonymous vote from that session is deleted and it can no longer vote on Hamme.',
          'Other open reports against the same session are resolved as actioned.'
        ],
        warning: sid ? '' : 'No session id was recorded for this vote, so there may be no session to ban. The vote will still be deleted.',
        confirmLabel: 'Remove & ban voter',
        danger: true,
        success: 'Vote removed and anonymous voter banned.'
      };
    }
    var body = [
      (kind === 'profile' ? 'Removes the profile photo' : 'Deletes this ' + vote) + ' and permanently bans ' + who + '.',
      'The ban signs them out everywhere, deletes every vote they sent and all of their matches, removes their profile photo and takes their public poll page offline. They cannot sign in or register again from the same device.',
      'Other open reports against this user are resolved as actioned.'
    ];
    if (r.anonymous) body.splice(1, 0, 'The vote was shown anonymously but was sent from this signed-in account, so the account is banned.');
    return {
      title: 'Remove & ban ' + who + '?',
      body: body,
      warning: r.reportedUserBanned ? 'This user is already banned.' : '',
      confirmLabel: 'Remove & ban',
      danger: true,
      success: (kind === 'profile' ? 'Profile photo removed' : 'Vote removed') + ' and ' + who + ' banned.'
    };
  }

  function openReportAction(r, action) {
    var cfg = describeAction(r, action);
    if (!cfg) return;
    openModal({
      title: cfg.title,
      body: cfg.body,
      warning: cfg.warning,
      inputLabel: 'Internal note (optional)',
      inputPlaceholder: 'Only admins see this, e.g. why you chose this action.',
      confirmLabel: cfg.confirmLabel,
      danger: cfg.danger,
      onConfirm: async function (note) {
        var payload = { action: action };
        if (note) payload.note = note;
        setCardBusy(r.id, true, 'Working…');
        try {
          return await api('/reports/' + encodeURIComponent(r.id) + '/action', { method: 'POST', body: JSON.stringify(payload) });
        } catch (e) {
          setCardBusy(r.id, false, e.message, 'err');
          throw e;
        }
      },
      onSuccess: function () {
        setCardBusy(r.id, true, 'Done. Refreshing…', 'ok');
        setReportStatus(cfg.success, 'ok');
        loadReports();
        if (action !== 'dismiss') load();
      }
    });
  }

  // ── Confirm dialog ────────────────────────────────────────────────────────
  var modal = { opts: null, busy: false, returnFocus: null };

  function openModal(opts) {
    modal.opts = opts;
    modal.busy = false;
    modal.returnFocus = document.activeElement;
    $('modalTitle').textContent = opts.title || 'Are you sure?';
    var body = $('modalBody');
    body.textContent = '';
    (opts.body || []).forEach(function (text) {
      if (!text) return;
      var p = document.createElement('p');
      p.textContent = text;
      body.appendChild(p);
    });
    if (opts.warning) {
      var w = document.createElement('p');
      w.className = 'modal-warning';
      w.textContent = opts.warning;
      body.appendChild(w);
    }
    $('modalField').hidden = !opts.inputLabel;
    $('modalInputLabel').textContent = opts.inputLabel || '';
    $('modalInput').value = '';
    $('modalInput').placeholder = opts.inputPlaceholder || '';
    $('modalInput').disabled = false;
    $('modalError').textContent = '';
    var confirmBtn = $('modalConfirm');
    confirmBtn.textContent = opts.confirmLabel || 'Confirm';
    confirmBtn.className = opts.danger ? 'btn-danger-solid' : 'btn-primary';
    confirmBtn.disabled = false;
    $('modalCancel').disabled = false;
    $('modal').hidden = false;
    document.body.classList.add('modal-open');
    $('modalDialog').focus();
  }

  function closeModal() {
    if (!modal.opts || modal.busy) return;
    $('modal').hidden = true;
    document.body.classList.remove('modal-open');
    var back = modal.returnFocus;
    modal.opts = null;
    modal.returnFocus = null;
    if (back && typeof back.focus === 'function' && document.body.contains(back)) back.focus();
  }

  function setModalBusy(busy) {
    modal.busy = busy;
    $('modalConfirm').disabled = busy;
    $('modalCancel').disabled = busy;
    $('modalInput').disabled = busy;
    $('modalConfirm').textContent = busy ? 'Working…' : (modal.opts && modal.opts.confirmLabel) || 'Confirm';
  }

  async function confirmModal() {
    var opts = modal.opts;
    if (!opts || modal.busy) return;
    var value = opts.inputLabel ? $('modalInput').value.trim() : '';
    $('modalError').textContent = '';
    setModalBusy(true);
    try {
      var result = await opts.onConfirm(value);
      setModalBusy(false);
      closeModal();
      if (opts.onSuccess) opts.onSuccess(result, value);
    } catch (e) {
      setModalBusy(false);
      $('modalError').textContent = (e && e.message) || 'Something went wrong.';
    }
  }

  $('modalCancel').addEventListener('click', closeModal);
  $('modalConfirm').addEventListener('click', confirmModal);
  // Close on a backdrop click, but not when a text selection drag ends outside.
  var backdropDown = false;
  $('modal').addEventListener('mousedown', function (e) { backdropDown = e.target === $('modal'); });
  $('modal').addEventListener('click', function (e) {
    if (backdropDown && e.target === $('modal')) closeModal();
    backdropDown = false;
  });
  document.addEventListener('keydown', function (e) {
    if (!modal.opts) return;
    if (e.key === 'Escape') { e.preventDefault(); closeModal(); return; }
    if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); confirmModal(); return; }
    if (e.key !== 'Tab') return;
    var dialog = $('modalDialog');
    var focusables = Array.prototype.filter.call(dialog.querySelectorAll('button, textarea'), function (el) {
      return !el.disabled && el.offsetParent !== null;
    });
    if (!focusables.length) { e.preventDefault(); return; }
    var first = focusables[0];
    var last = focusables[focusables.length - 1];
    var active = document.activeElement;
    if (e.shiftKey && (active === first || active === dialog)) { e.preventDefault(); last.focus(); }
    else if (!e.shiftKey && (active === last || !dialog.contains(active))) { e.preventDefault(); first.focus(); }
  });

  // ── Wiring ────────────────────────────────────────────────────────────────
  function saveAndLoad() {
    var key = $('adminKey').value.trim();
    setKey(key);
    if (!key) { setStatus('Enter your admin key first.', 'err'); return; }
    setStatus('Key saved.', 'ok');
    state.page = 1;
    reportState.page = 1;
    load();
    loadSettings();
    loadReports();
  }

  $('saveKey').addEventListener('click', saveAndLoad);
  $('adminKey').addEventListener('keydown', function (e) {
    if (e.key === 'Enter') saveAndLoad();
  });

  var searchTimer = null;
  $('search').addEventListener('input', function (e) {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(function () {
      state.search = e.target.value.trim();
      state.page = 1;
      load();
    }, 350);
  });

  $('prev').addEventListener('click', function () {
    if (state.page > 1) { state.page--; load(); }
  });
  $('next').addEventListener('click', function () {
    if (state.page < state.pages) { state.page++; load(); }
  });

  $('rows').addEventListener('click', function (e) {
    var b = e.target.closest ? e.target.closest('button[data-id]') : null;
    if (!b || b.disabled) return;
    var id = b.getAttribute('data-id');
    if (b.hasAttribute('data-pro')) { setPlan(id, b.getAttribute('data-pro') === 'true'); return; }
    var u = state.byId[id];
    if (!u) return;
    if (b.getAttribute('data-ban') === 'ban') openBan(u);
    else if (b.getAttribute('data-ban') === 'unban') openUnban(u);
  });

  function scrollToReports() {
    $('reports').scrollIntoView({ behavior: 'smooth', block: 'start' });
  }

  $('reportRefresh').addEventListener('click', loadReports);
  $('reportStaleRefresh').addEventListener('click', loadReports);
  each(document.querySelectorAll('.report-prev'), function (b) {
    b.addEventListener('click', function () {
      if (reportState.page <= 1) return;
      reportState.page--;
      var fromBottom = !!b.closest('.pager-bottom');
      loadReports().then(function () { if (fromBottom) scrollToReports(); });
    });
  });
  each(document.querySelectorAll('.report-next'), function (b) {
    b.addEventListener('click', function () {
      if (reportState.page >= reportState.pages) return;
      reportState.page++;
      var fromBottom = !!b.closest('.pager-bottom');
      loadReports().then(function () { if (fromBottom) scrollToReports(); });
    });
  });
  each(document.querySelectorAll('#reportTabs [data-status]'), function (tab) {
    tab.addEventListener('click', function () { setReportFilter(tab.getAttribute('data-status')); });
  });
  $('overdueShow').addEventListener('click', function () { setReportFilter('open'); });
  each([$('hdrOpen'), $('hdrOverdue')], function (a) {
    a.addEventListener('click', function () {
      if (reportState.status !== 'open') setReportFilter('open');
    });
  });

  $('reportList').addEventListener('click', function (e) {
    if (!e.target.closest) return;
    var findBtn = e.target.closest('[data-find]');
    if (findBtn) { findUser(findBtn.getAttribute('data-find')); return; }
    var b = e.target.closest('button[data-action]');
    if (!b || b.disabled) return;
    var r = reportState.byId[b.getAttribute('data-id')];
    if (r) openReportAction(r, b.getAttribute('data-action'));
  });

  // Keep the open/overdue counters fresh while the page is open.
  setInterval(function () {
    refreshCounters();
    tickAges();
  }, COUNTER_POLL_MS);
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) return;
    tickAges();
    if (Date.now() - counterState.lastAt > 15000) refreshCounters();
  });

  // ── Settings ──────────────────────────────────────────────────────────────
  function setSettingsStatus(msg, kind) {
    var el = $('settingsStatus');
    el.textContent = msg || '';
    el.className = kind || '';
  }

  async function loadSettings() {
    if (!getKey()) return;
    try {
      var data = await api('/config');
      if (data && data.config) {
        $('cardLimit').value = data.config.freeUserCardLimit || 10;
        $('cooldownMinutes').value = data.config.cardCooldownMinutes || 5;
      }
    } catch (e) {
      // Non-fatal: leave placeholders
    }
  }

  $('saveSettings').addEventListener('click', async function () {
    if (!getKey()) { setSettingsStatus('Enter your admin key first.', 'err'); return; }
    var cardLimit = parseInt($('cardLimit').value, 10);
    var cooldown = parseInt($('cooldownMinutes').value, 10);
    if (!cardLimit || cardLimit < 1) { setSettingsStatus('Card limit must be at least 1.', 'err'); return; }
    if (!cooldown || cooldown < 1) { setSettingsStatus('Cooldown must be at least 1 minute.', 'err'); return; }
    setSettingsStatus('Saving…');
    try {
      await api('/config', { method: 'PATCH', body: JSON.stringify({ freeUserCardLimit: cardLimit, cardCooldownMinutes: cooldown }) });
      setSettingsStatus('Settings saved!', 'ok');
    } catch (e) {
      setSettingsStatus(e.message, 'err');
    }
  });

  // Restore saved key on open.
  $('adminKey').value = getKey();
  if (getKey()) { load(); loadSettings(); loadReports(); }
</script>
</body>
</html>`;

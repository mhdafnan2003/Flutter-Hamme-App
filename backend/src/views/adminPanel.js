// Self-contained admin panel HTML (no external assets) for managing user plans.
module.exports = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Hamme Admin · Plans</title>
<style>
  :root { --purple:#7838FE; --purple2:#9E57FF; --bg:#f5f5f7; --line:#e6e6ef; }
  * { box-sizing: border-box; }
  body { margin:0; font-family: -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; background:var(--bg); color:#1c1c28; }
  header { background:linear-gradient(90deg,var(--purple2),var(--purple)); color:#fff; padding:18px 24px; }
  header h1 { margin:0; font-size:20px; font-weight:800; }
  header p { margin:4px 0 0; opacity:.9; font-size:13px; }
  .wrap { max-width:1000px; margin:0 auto; padding:20px 16px 60px; }
  .card { background:#fff; border:1px solid var(--line); border-radius:14px; padding:16px; margin-bottom:16px; }
  label { font-size:12px; font-weight:700; color:#6b6b80; display:block; margin-bottom:6px; }
  input { width:100%; padding:10px 12px; border:1px solid var(--line); border-radius:10px; font-size:14px; }
  .row { display:flex; gap:12px; flex-wrap:wrap; align-items:flex-end; }
  .row > div { flex:1; min-width:200px; }
  button { cursor:pointer; border:none; border-radius:10px; padding:10px 14px; font-weight:700; font-size:14px; }
  .btn-primary { background:var(--purple); color:#fff; }
  .btn-ghost { background:#f0eefe; color:var(--purple); }
  .btn-danger { background:#ffe9e9; color:#d33; }
  table { width:100%; border-collapse:collapse; }
  th, td { text-align:left; padding:10px 8px; border-bottom:1px solid var(--line); font-size:14px; vertical-align:middle; }
  th { font-size:11px; text-transform:uppercase; letter-spacing:.04em; color:#9a9aae; }
  .avatar { width:38px; height:38px; border-radius:50%; object-fit:cover; background:#eee; }
  .badge { display:inline-block; padding:3px 10px; border-radius:999px; font-size:12px; font-weight:800; }
  .badge.pro { background:#efeaff; color:var(--purple); }
  .badge.free { background:#eef0f3; color:#7a7a8c; }
  .muted { color:#9a9aae; font-size:12px; }
  .toolbar { display:flex; justify-content:space-between; align-items:center; margin-bottom:8px; gap:12px; flex-wrap:wrap; }
  .pager { display:flex; gap:8px; align-items:center; }
  #status { font-size:13px; min-height:18px; }
  .err { color:#d33; }
  .ok { color:#1a8f3c; }
</style>
</head>
<body>
<header>
  <h1>Hamme Admin · Plan Manager</h1>
  <p>List users and switch their plan between Free and Pro.</p>
</header>
<div class="wrap">
  <div class="card">
    <div class="row">
      <div>
        <label>Admin key</label>
        <input id="adminKey" type="password" placeholder="Enter ADMIN_API_KEY" />
      </div>
      <div style="flex:0 0 auto;">
        <button class="btn-primary" id="saveKey">Save & Load</button>
      </div>
      <div>
        <label>Search (name, username, email, code)</label>
        <input id="search" type="text" placeholder="Type to search…" />
      </div>
    </div>
    <div id="status" style="margin-top:10px;"></div>
  </div>

  <div class="card">
    <div class="toolbar">
      <div class="muted" id="summary">No data loaded.</div>
      <div class="pager">
        <button class="btn-ghost" id="prev">‹ Prev</button>
        <span class="muted" id="pageInfo">–</span>
        <button class="btn-ghost" id="next">Next ›</button>
      </div>
    </div>
    <table>
      <thead>
        <tr><th></th><th>Name</th><th>Username / Email</th><th>Share code</th><th>Plan</th><th>Action</th></tr>
      </thead>
      <tbody id="rows"><tr><td colspan="6" class="muted">Enter your admin key and click “Save & Load”.</td></tr></tbody>
    </table>
  </div>
</div>

<script>
  var API_BASE = location.pathname.replace(/\\/$/, '');
  var state = { page: 1, limit: 25, search: '', pages: 1 };
  var $ = function (id) { return document.getElementById(id); };

  function getKey() { return localStorage.getItem('hamme_admin_key') || ''; }
  function setKey(v) { localStorage.setItem('hamme_admin_key', v); }

  function setStatus(msg, kind) {
    var el = $('status');
    el.textContent = msg || '';
    el.className = kind || '';
  }

  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c];
    });
  }

  async function api(path, options) {
    options = options || {};
    options.headers = Object.assign({ 'x-admin-key': getKey(), 'Content-Type': 'application/json' }, options.headers || {});
    var res = await fetch(API_BASE + path, options);
    var data = null;
    try { data = await res.json(); } catch (e) {}
    if (!res.ok) {
      var message = (data && data.message) || ('Request failed (' + res.status + ')');
      throw new Error(message);
    }
    return data;
  }

  function render(data) {
    var tbody = $('rows');
    state.pages = data.pages;
    $('summary').textContent = data.total + ' user(s) total';
    $('pageInfo').textContent = 'Page ' + data.page + ' / ' + data.pages;
    if (!data.users.length) {
      tbody.innerHTML = '<tr><td colspan="6" class="muted">No users found.</td></tr>';
      return;
    }
    tbody.innerHTML = data.users.map(function (u) {
      var isPro = !!u.isPro;
      var avatar = u.avatarUrl ? '<img class="avatar" src="' + escapeHtml(u.avatarUrl) + '" onerror="this.style.visibility=\\'hidden\\'"/>' : '<div class="avatar"></div>';
      var badge = isPro ? '<span class="badge pro">PRO</span>' : '<span class="badge free">FREE</span>';
      var btn = isPro
        ? '<button class="btn-danger" data-id="' + u.id + '" data-pro="false">Downgrade to Free</button>'
        : '<button class="btn-primary" data-id="' + u.id + '" data-pro="true">Upgrade to Pro</button>';
      return '<tr>' +
        '<td>' + avatar + '</td>' +
        '<td>' + escapeHtml(u.name) + '</td>' +
        '<td>' + escapeHtml(u.username || '') + '<div class="muted">' + escapeHtml(u.email || '') + '</div></td>' +
        '<td><span class="muted">' + escapeHtml(u.shareCode || '') + '</span></td>' +
        '<td>' + badge + '</td>' +
        '<td>' + btn + '</td>' +
      '</tr>';
    }).join('');

    Array.prototype.forEach.call(tbody.querySelectorAll('button[data-id]'), function (b) {
      b.addEventListener('click', function () {
        setPlan(b.getAttribute('data-id'), b.getAttribute('data-pro') === 'true');
      });
    });
  }

  async function load() {
    if (!getKey()) { setStatus('Enter your admin key first.', 'err'); return; }
    setStatus('Loading…');
    try {
      var q = '/users?page=' + state.page + '&limit=' + state.limit + '&search=' + encodeURIComponent(state.search);
      var data = await api(q);
      render(data);
      setStatus('Loaded.', 'ok');
    } catch (e) {
      setStatus(e.message, 'err');
    }
  }

  async function setPlan(id, isPro) {
    setStatus('Updating…');
    try {
      await api('/users/' + id + '/plan', { method: 'PATCH', body: JSON.stringify({ isPro: isPro }) });
      setStatus('Updated to ' + (isPro ? 'PRO' : 'FREE') + '.', 'ok');
      load();
    } catch (e) {
      setStatus(e.message, 'err');
    }
  }

  $('saveKey').addEventListener('click', function () {
    setKey($('adminKey').value.trim());
    state.page = 1;
    load();
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

  // Restore saved key on open.
  $('adminKey').value = getKey();
  if (getKey()) load();
</script>
</body>
</html>`;

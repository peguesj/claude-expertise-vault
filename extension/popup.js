/* Claude Expertise Vault — Popup Logic */

const DEFAULT_SERVER = 'http://localhost:8645';

let currentMode = 'search';
let serverUrl = DEFAULT_SERVER;

// DOM Elements
const queryInput = document.getElementById('query-input');
const submitBtn = document.getElementById('submit-btn');
const submitText = document.getElementById('submit-text');
const submitSpinner = document.getElementById('submit-spinner');
const resultsArea = document.getElementById('results-area');
const statusDot = document.getElementById('status-dot');
const btnSearch = document.getElementById('btn-search');
const btnAsk = document.getElementById('btn-ask');
const statPosts = document.getElementById('stat-posts');
const statChunks = document.getElementById('stat-chunks');
const statExperts = document.getElementById('stat-experts');

// Initialize
document.addEventListener('DOMContentLoaded', async () => {
  await loadServerUrl();
  checkHealth();
  loadStats();

  // Mode toggle
  btnSearch.addEventListener('click', () => setMode('search'));
  btnAsk.addEventListener('click', () => setMode('ask'));

  // Submit
  submitBtn.addEventListener('click', handleSubmit);
  queryInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit();
    }
  });
});

async function loadServerUrl() {
  try {
    const result = await chrome.storage.sync.get('serverUrl');
    if (result.serverUrl) {
      serverUrl = result.serverUrl;
    }
  } catch {
    serverUrl = DEFAULT_SERVER;
  }
}

function setMode(mode) {
  currentMode = mode;
  btnSearch.classList.toggle('active', mode === 'search');
  btnAsk.classList.toggle('active', mode === 'ask');
  submitText.textContent = mode === 'search' ? 'Search' : 'Ask';
  queryInput.placeholder = mode === 'search'
    ? 'Search the expertise vault...'
    : 'Ask a question about Claude Code...';
}

async function handleSubmit() {
  const query = queryInput.value.trim();
  if (!query) return;

  setLoading(true);
  const startTime = performance.now();

  try {
    if (currentMode === 'search') {
      await performSearch(query, startTime);
    } else {
      await performAsk(query, startTime);
    }
  } catch (err) {
    showError(err.message);
  } finally {
    setLoading(false);
  }
}

async function performSearch(query, startTime) {
  const params = new URLSearchParams({
    q: query,
    top_k: '5',
    min_score: '0.2'
  });

  const res = await fetch(`${serverUrl}/api/search?${params}`);
  if (!res.ok) throw new Error(`Search failed (${res.status})`);

  const data = await res.json();
  const latency = Math.round(performance.now() - startTime);

  logSearchAnalytics(query, 'search', data.results?.length || 0, latency);
  renderSearchResults(data.results || []);
}

async function performAsk(query, startTime) {
  const params = new URLSearchParams({
    q: query,
    top_k: '8'
  });

  const res = await fetch(`${serverUrl}/api/ask?${params}`);
  if (!res.ok) throw new Error(`Ask failed (${res.status})`);

  const data = await res.json();
  const latency = Math.round(performance.now() - startTime);

  logSearchAnalytics(query, 'ask', data.citations?.length || 0, latency);
  renderAskResult(data);
}

function renderSearchResults(results) {
  if (!results.length) {
    resultsArea.innerHTML = '<div class="empty-state"><p>No results found</p></div>';
    return;
  }

  resultsArea.innerHTML = results.map((r, i) => {
    const score = r.score || r.similarity || 0;
    const scorePercent = Math.round(score * 100);
    const scoreClass = score >= 0.6 ? 'high' : score >= 0.35 ? 'medium' : 'low';
    const author = r.author || r.metadata?.author || 'Unknown';
    const date = r.date || r.metadata?.date || '';
    const text = r.text || r.content || r.chunk || '';
    const truncated = text.length > 300 ? text.slice(0, 300) + '...' : text;
    const url = r.url || r.metadata?.url || '';
    const tags = r.tags || r.metadata?.tags || [];

    return `
      <div class="result-card" data-index="${i}">
        <div class="result-header">
          <span class="result-author">${escapeHtml(author)}</span>
          <span class="result-date">${escapeHtml(formatDate(date))}</span>
        </div>
        <div class="result-text">${escapeHtml(truncated)}</div>
        <div class="result-footer">
          <div class="score-bar-container">
            <div class="score-bar ${scoreClass}" style="width: ${scorePercent}%"></div>
          </div>
          <span class="score-label">${scorePercent}%</span>
          <div class="result-tags">
            ${tags.slice(0, 3).map(t => `<span class="tag">${escapeHtml(t)}</span>`).join('')}
          </div>
        </div>
        ${url ? `<a href="${escapeHtml(url)}" target="_blank" rel="noopener" class="result-link">View source</a>` : ''}
      </div>
    `;
  }).join('');
}

function renderAskResult(data) {
  const answer = data.answer || data.response || 'No answer generated.';
  const citations = data.citations || data.sources || [];

  let html = `
    <div class="answer-container">
      <div class="answer-label">Answer</div>
      <div class="answer-text">${escapeHtml(answer)}</div>
    </div>
  `;

  if (citations.length > 0) {
    html += '<div class="citations-label">Sources</div>';
    html += citations.map((c, i) => {
      const score = c.score || c.similarity || 0;
      const scorePercent = Math.round(score * 100);
      const scoreClass = score >= 0.6 ? 'high' : score >= 0.35 ? 'medium' : 'low';
      const author = c.author || c.metadata?.author || 'Unknown';
      const text = c.text || c.content || c.chunk || '';
      const truncated = text.length > 200 ? text.slice(0, 200) + '...' : text;
      const url = c.url || c.metadata?.url || '';

      return `
        <div class="result-card">
          <div class="result-header">
            <span class="result-author">[${i + 1}] ${escapeHtml(author)}</span>
          </div>
          <div class="result-text">${escapeHtml(truncated)}</div>
          <div class="result-footer">
            <div class="score-bar-container">
              <div class="score-bar ${scoreClass}" style="width: ${scorePercent}%"></div>
            </div>
            <span class="score-label">${scorePercent}%</span>
          </div>
          ${url ? `<a href="${escapeHtml(url)}" target="_blank" rel="noopener" class="result-link">View source</a>` : ''}
        </div>
      `;
    }).join('');
  }

  resultsArea.innerHTML = html;
}

function showError(message) {
  resultsArea.innerHTML = `
    <div class="error-message">
      ${escapeHtml(message)}
    </div>
  `;
}

function setLoading(loading) {
  submitBtn.disabled = loading;
  submitSpinner.classList.toggle('hidden', !loading);
  submitText.style.opacity = loading ? '0.5' : '1';
}

async function checkHealth() {
  try {
    const res = await fetch(`${serverUrl}/api/health`, { signal: AbortSignal.timeout(5000) });
    const online = res.ok;
    statusDot.classList.toggle('online', online);
    statusDot.classList.toggle('offline', !online);
    statusDot.title = online ? 'Server online' : 'Server offline';
  } catch {
    statusDot.classList.remove('online');
    statusDot.classList.add('offline');
    statusDot.title = 'Server offline';
  }
}

async function loadStats() {
  try {
    const res = await fetch(`${serverUrl}/api/stats`, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return;
    const data = await res.json();
    statPosts.textContent = data.posts || data.total_posts || '--';
    statChunks.textContent = data.chunks || data.total_chunks || '--';
    statExperts.textContent = data.experts || data.total_experts || data.authors || '--';
  } catch {
    // Stats unavailable
  }
}

async function logSearchAnalytics(query, mode, resultCount, latencyMs) {
  try {
    await fetch(`${serverUrl}/api/analytics/search`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        query,
        mode,
        result_count: resultCount,
        latency_ms: latencyMs
      })
    });
  } catch {
    // Analytics logging is best-effort
  }
}

function escapeHtml(str) {
  if (!str) return '';
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}

function formatDate(dateStr) {
  if (!dateStr) return '';
  try {
    const d = new Date(dateStr);
    if (isNaN(d.getTime())) return dateStr;
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
  } catch {
    return dateStr;
  }
}

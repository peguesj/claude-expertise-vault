/* Claude Expertise Vault — Background Service Worker */

const DEFAULT_SERVER = 'http://localhost:8645';
const HEALTH_CHECK_INTERVAL_MS = 60000;

let serverUrl = DEFAULT_SERVER;
let isOnline = false;

// Initialize on install
chrome.runtime.onInstalled.addListener(async () => {
  await loadServerUrl();
  setupContextMenu();
  await checkHealth();
  startHealthCheckAlarm();
});

// Initialize on startup
chrome.runtime.onStartup.addListener(async () => {
  await loadServerUrl();
  setupContextMenu();
  await checkHealth();
  startHealthCheckAlarm();
});

// Listen for storage changes (options page updates)
chrome.storage.onChanged.addListener((changes, area) => {
  if (area === 'sync' && changes.serverUrl) {
    serverUrl = changes.serverUrl.newValue || DEFAULT_SERVER;
    checkHealth();
  }
});

// Alarm-based health check
function startHealthCheckAlarm() {
  chrome.alarms.create('healthCheck', {
    periodInMinutes: 1
  });
}

chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'healthCheck') {
    checkHealth();
  }
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

async function checkHealth() {
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    const res = await fetch(`${serverUrl}/api/health`, {
      signal: controller.signal
    });
    clearTimeout(timeoutId);

    isOnline = res.ok;
  } catch {
    isOnline = false;
  }

  updateBadge();
}

function updateBadge() {
  if (isOnline) {
    chrome.action.setBadgeText({ text: 'ON' });
    chrome.action.setBadgeBackgroundColor({ color: '#22c55e' });
  } else {
    chrome.action.setBadgeText({ text: 'OFF' });
    chrome.action.setBadgeBackgroundColor({ color: '#ef4444' });
  }
}

// Context menu
function setupContextMenu() {
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: 'send-to-vault',
      title: 'Send to Expertise Vault',
      contexts: ['selection']
    });
  });
}

chrome.contextMenus.onClicked.addListener(async (info, tab) => {
  if (info.menuItemId !== 'send-to-vault') return;

  const selectedText = info.selectionText;
  if (!selectedText) return;

  await loadServerUrl();

  const post = {
    id: `ext-${Date.now()}`,
    author: 'extension-user',
    date: new Date().toISOString(),
    url: tab?.url || '',
    text: selectedText,
    media: [],
    links: [],
    likes: 0,
    comments: 0,
    reposts: 0,
    tags: ['extension-capture'],
    platform: detectPlatform(tab?.url || '')
  };

  try {
    const res = await fetch(`${serverUrl}/api/ingest`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ posts: [post] })
    });

    if (res.ok) {
      chrome.action.setBadgeText({ text: '+1' });
      chrome.action.setBadgeBackgroundColor({ color: '#7c3aed' });
      setTimeout(() => updateBadge(), 2000);
    } else {
      chrome.action.setBadgeText({ text: 'ERR' });
      chrome.action.setBadgeBackgroundColor({ color: '#ef4444' });
      setTimeout(() => updateBadge(), 3000);
    }
  } catch {
    chrome.action.setBadgeText({ text: 'ERR' });
    chrome.action.setBadgeBackgroundColor({ color: '#ef4444' });
    setTimeout(() => updateBadge(), 3000);
  }
});

function detectPlatform(url) {
  if (!url) return 'other';
  if (url.includes('twitter.com') || url.includes('x.com')) return 'x';
  if (url.includes('linkedin.com')) return 'linkedin';
  if (url.includes('github.com')) return 'github';
  if (url.includes('youtube.com')) return 'youtube';
  if (url.includes('reddit.com')) return 'reddit';
  if (url.includes('news.ycombinator.com')) return 'hackernews';
  return 'other';
}

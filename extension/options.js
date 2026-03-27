/* Claude Expertise Vault — Options Page Logic */

const DEFAULT_SERVER = 'http://localhost:8645';

const serverUrlInput = document.getElementById('server-url');
const saveBtn = document.getElementById('save-btn');
const saveStatus = document.getElementById('save-status');
const testBtn = document.getElementById('test-btn');
const testResult = document.getElementById('test-result');

// Load saved settings
document.addEventListener('DOMContentLoaded', async () => {
  try {
    const result = await chrome.storage.sync.get('serverUrl');
    serverUrlInput.value = result.serverUrl || DEFAULT_SERVER;
  } catch {
    serverUrlInput.value = DEFAULT_SERVER;
  }

  saveBtn.addEventListener('click', saveSettings);
  testBtn.addEventListener('click', testConnection);
});

async function saveSettings() {
  const url = serverUrlInput.value.trim() || DEFAULT_SERVER;

  // Normalize: remove trailing slash
  const normalized = url.replace(/\/+$/, '');
  serverUrlInput.value = normalized;

  try {
    await chrome.storage.sync.set({ serverUrl: normalized });
    showSaveStatus('Saved', 'success');
  } catch (err) {
    showSaveStatus('Failed to save: ' + err.message, 'error');
  }
}

async function testConnection() {
  const url = (serverUrlInput.value.trim() || DEFAULT_SERVER).replace(/\/+$/, '');

  testBtn.disabled = true;
  testBtn.textContent = 'Testing...';
  testResult.classList.remove('hidden');
  testResult.className = 'test-result';
  testResult.textContent = 'Connecting...';

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    const res = await fetch(`${url}/api/health`, {
      signal: controller.signal
    });
    clearTimeout(timeoutId);

    if (res.ok) {
      const data = await res.json().catch(() => ({}));
      testResult.className = 'test-result success';
      testResult.textContent = `Connected successfully. ${data.status || 'Server is healthy.'}`;
    } else {
      testResult.className = 'test-result error';
      testResult.textContent = `Server responded with status ${res.status}`;
    }
  } catch (err) {
    testResult.className = 'test-result error';
    if (err.name === 'AbortError') {
      testResult.textContent = 'Connection timed out (5s). Is the server running?';
    } else {
      testResult.textContent = `Connection failed: ${err.message}`;
    }
  } finally {
    testBtn.disabled = false;
    testBtn.textContent = 'Test';
  }
}

function showSaveStatus(message, type) {
  saveStatus.textContent = message;
  saveStatus.className = `save-status ${type}`;
  saveStatus.classList.remove('hidden');

  setTimeout(() => {
    saveStatus.classList.add('hidden');
  }, 3000);
}

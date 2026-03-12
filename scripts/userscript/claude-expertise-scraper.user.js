// ==UserScript==
// @name         Claude Expertise Scraper
// @namespace    https://github.com/peguesj/claude-expertise-vault
// @version      4.0.0
// @description  Intelligent knowledge extraction with AI refinement, analytics, and server sync for the Claude Expertise Vault
// @author       Claude Expertise Vault
// @match        *://*/*
// @grant        GM_setClipboard
// @grant        GM_xmlhttpRequest
// @grant        GM_addStyle
// @connect      localhost
// @connect      api.anthropic.com
// @run-at       document-idle
// @noframes
// ==/UserScript==

(function () {
  "use strict";

  const DEFAULT_SERVER = "http://localhost:8645";
  const DEFAULT_INGEST_API = DEFAULT_SERVER + "/api/ingest";
  const ANTHROPIC_API = "https://api.anthropic.com/v1/messages";

  // ── Server Health ──────────────────────────────────────────────────────────
  let serverOnline = false;

  function getServerUrl() { return getS("server_url", DEFAULT_SERVER); }

  function checkServerHealth() {
    const url = getServerUrl() + "/api/health";
    if (typeof GM_xmlhttpRequest === "function") {
      GM_xmlhttpRequest({
        method: "GET", url: url, timeout: 5000,
        onload: function (r) { serverOnline = r.status < 300; updateFabBadge(); },
        onerror: function () { serverOnline = false; updateFabBadge(); },
        ontimeout: function () { serverOnline = false; updateFabBadge(); }
      });
    } else {
      fetch(url, { signal: AbortSignal.timeout(5000) })
        .then(function (r) { serverOnline = r.ok; updateFabBadge(); })
        .catch(function () { serverOnline = false; updateFabBadge(); });
    }
  }

  function updateFabBadge() {
    if (!fabBtn) return;
    let dot = fabBtn.querySelector(".cev-health-dot");
    if (!dot) {
      dot = document.createElement("span");
      dot.className = "cev-health-dot";
      dot.setAttribute("style", "position:absolute !important; bottom:-2px !important; right:-2px !important; width:10px !important; height:10px !important; border-radius:50% !important; border:2px solid #0f0f1a !important;");
      fabBtn.appendChild(dot);
    }
    dot.style.background = serverOnline ? "#22c55e" : "#ef4444";
    dot.style.boxShadow = serverOnline ? "0 0 6px #22c55e" : "0 0 6px #ef4444";
  }

  // ── Analytics ──────────────────────────────────────────────────────────────
  function logAnalytics(type, data) {
    const url = getServerUrl() + "/api/analytics/" + type;
    const body = JSON.stringify(data);
    if (typeof GM_xmlhttpRequest === "function") {
      GM_xmlhttpRequest({
        method: "POST", url: url, headers: { "Content-Type": "application/json" }, data: body,
        onload: function () {}, onerror: function () {}
      });
    } else {
      fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: body }).catch(function () {});
    }
  }

  function trackIngest(posts) {
    posts.forEach(function (p) {
      logAnalytics("interaction", { query: "ingest:" + (p.author || "unknown"), post_id: p.id, action: "ingest", dwell_ms: 0 });
    });
  }

  // ── Settings ──────────────────────────────────────────────────────────────
  function getS(k, d) { try { const v = localStorage.getItem("cev_" + k); return v === null ? d : JSON.parse(v); } catch { return d; } }
  function setS(k, v) { try { localStorage.setItem("cev_" + k, JSON.stringify(v)); } catch {} }

  // ── Platform Detection ────────────────────────────────────────────────────
  function detectPlatform() {
    const h = location.hostname.replace("www.", "");
    if (h.includes("linkedin.com")) return "linkedin";
    if (h.includes("twitter.com") || h.includes("x.com")) return "x";
    if (h.includes("github.com")) return "github";
    if (h.includes("youtube.com")) return "youtube";
    if (h.includes("news.ycombinator.com")) return "hackernews";
    if (h.includes("reddit.com")) return "reddit";
    return "blog";
  }

  // ── Utils ─────────────────────────────────────────────────────────────────
  function txt(el) { return el ? el.innerText.trim() : ""; }
  function parseNum(s) {
    if (!s) return 0;
    s = s.replace(/,/g, "").trim();
    const m = s.match(/([\d.]+)\s*([KkMm]?)/);
    if (!m) return 0;
    let n = parseFloat(m[1]);
    if (/[Kk]/.test(m[2])) n *= 1000;
    if (/[Mm]/.test(m[2])) n *= 1e6;
    return Math.round(n);
  }
  function hashStr(s) { let h = 0; for (let i = 0; i < s.length; i++) h = ((h << 5) - h + s.charCodeAt(i)) | 0; return Math.abs(h).toString(36); }
  function esc(s) { return (s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;"); }

  // ── Intelligent Link Extraction ───────────────────────────────────────────

  const LINK_BLOCKLIST = [
    /linkedin\.com\/(feed|search|ads|in\/[^/]+$|mynetwork|notifications|jobs$|messaging)/,
    /linkedin\.com\/(?:company|school)\/[^/]+$/,
    /twitter\.com\/(home|explore|notifications|messages|settings)/,
    /x\.com\/(home|explore|notifications|messages|settings)/,
    /facebook\.com\/(home|notifications|bookmarks|watch)/,
    /google\.com\/(search|maps|mail|drive)/,
    /\/(login|signin|signup|register|auth|oauth|sso)\b/,
    /\/(privacy|terms|cookie|gdpr|tos|legal)\b/i,
    /\/(ads|sponsored|promo|campaign|tracking)\b/,
    /doubleclick|googlesyndication|googletagmanager|analytics|pixel|beacon/,
    /^javascript:/,
    /#$/,
  ];

  const LINK_CLASSIFIERS = [
    { re: /github\.com\/[\w-]+\/[\w.-]+/, type: "github-repo", weight: 0.95 },
    { re: /github\.com\/[\w-]+\/[\w.-]+\/(issues|pull|discussions|wiki)/, type: "github-thread", weight: 0.85 },
    { re: /(?:arxiv\.org|papers\.ssrn|doi\.org|scholar\.google)/, type: "paper", weight: 0.9 },
    { re: /(?:pypi\.org|npmjs\.com|crates\.io|hex\.pm)\/(?:project|package)\//, type: "package", weight: 0.9 },
    { re: /(?:docs\.|documentation|readme|wiki)/, type: "documentation", weight: 0.85 },
    { re: /(?:youtube\.com\/watch|youtu\.be\/)/, type: "video", weight: 0.8 },
    { re: /(?:huggingface\.co|ollama\.com\/library)/, type: "model", weight: 0.9 },
    { re: /(?:medium\.com|dev\.to|hashnode|substack|blog)/, type: "article", weight: 0.75 },
    { re: /(?:news\.ycombinator|reddit\.com\/r\/)/, type: "discussion", weight: 0.7 },
    { re: /\.(?:pdf|ipynb)(?:\?|$)/, type: "document", weight: 0.85 },
  ];

  function classifyLink(url) {
    for (const { re, type, weight } of LINK_CLASSIFIERS) {
      if (re.test(url)) return { type, weight };
    }
    return { type: "link", weight: 0.4 };
  }

  function isBlockedLink(url) {
    return LINK_BLOCKLIST.some(re => re.test(url));
  }

  function extractInlineUrls(text) {
    if (!text) return [];
    const re = /https?:\/\/[^\s<>"')\]]+/g;
    const matches = text.match(re) || [];
    return matches.map(u => u.replace(/[.,;:!?)]+$/, "")).filter(u => u.length > 10 && u.length < 2000);
  }

  function collectLinks(root, textContent) {
    const seen = new Set();
    const results = [];
    if (root) {
      for (const a of root.querySelectorAll("a[href]")) {
        const href = a.href;
        if (!href || !href.startsWith("http") || seen.has(href) || isBlockedLink(href)) continue;
        seen.add(href);
        const { type, weight } = classifyLink(href);
        const label = a.innerText.trim().slice(0, 80) || "";
        results.push({ url: href, type, label, weight, source: "dom" });
      }
    }
    for (const url of extractInlineUrls(textContent)) {
      if (seen.has(url) || isBlockedLink(url)) continue;
      seen.add(url);
      const { type, weight } = classifyLink(url);
      results.push({ url, type, label: "", weight, source: "text" });
    }
    results.sort((a, b) => b.weight - a.weight);
    return results.slice(0, 20);
  }

  function collectImgs(root) {
    if (!root) return [];
    const seen = new Set();
    return [...root.querySelectorAll("img")]
      .map(i => i.src || i.dataset.src || "")
      .filter(u => {
        if (!u.startsWith("http") || seen.has(u)) return false;
        if (u.length > 2000) return false;
        if (/emoji|avatar|icon|\/ad[-_]|badge|logo|profile.*photo|\.gif\?|pixel|spacer|1x1/i.test(u)) return false;
        if (!/\.(jpe?g|png|webp|svg|avif)|media\.licdn|pbs\.twimg|imgur|i\.redd/i.test(u)) return false;
        seen.add(u);
        return true;
      })
      .slice(0, 8);
  }

  // ── Auto-Tagging ─────────────────────────────────────────────────────────
  const TAG_RULES = [
    [/\bclaude\s+code\b/i, "claude-code"],
    [/\bclaude\b/i, "claude"],
    [/\bagent.*swarm|multi[- ]?agent|swarm\s+mode/i, "agent-swarms"],
    [/\bcoding\s+agent|ai\s+coding|agentic.*cod/i, "coding-agents"],
    [/\blocal(?:ly)?\s+(?:ai|llm|model|inference)|on[- ]?device|self[- ]?hosted/i, "local-ai"],
    [/\bhook(?:s)?\b/i, "hooks"],
    [/\bmcp\b/i, "mcp"],
    [/\bworktree\b/i, "worktree-isolation"],
    [/\bbenchmark|swe[- ]?bench/i, "benchmarks"],
    [/\bgpu\b|\bvram\b|\bhardware\b/i, "hardware"],
    [/\bquantiz/i, "quantization"],
    [/\bcontext\s+(?:window|engineer|management)/i, "context-management"],
    [/\bopen[- ]?source/i, "open-source"],
    [/\bvllm\b/i, "vllm"],
    [/\bdspy\b/i, "dspy"],
    [/\bkv[- ]?cache/i, "kv-cache-management"],
    [/\btoken\s+optim|reducing\s+token/i, "token-optimization"],
    [/\bself[- ]?improv/i, "self-improving-agents"],
    [/\bheadless\b.*(?:dev|workflow|agent)/i, "headless-dev"],
    [/\bcontext\s+engineer/i, "context-engineering"],
    [/\bsub[- ]?agent|agent\s+hierarch/i, "agent-hierarchy"],
    [/\bsecurity\b.*(?:audit|scan)/i, "security"],
    [/\bci\/?cd\b|\bpipeline\b|\bdeployment/i, "devops"],
    [/\bcursor\b/i, "cursor"],
    [/\bcopilot\b/i, "copilot"],
    [/\bopencode\b/i, "opencode"],
    [/\bprompt\s+engineer/i, "prompt-engineering"],
    [/\bfine[- ]?tun/i, "fine-tuning"],
    [/\brag\b|retrieval.augmented/i, "rag"],
    [/\bfunction\s+call|tool\s+use|tool\s+call/i, "tool-use"],
  ];

  function autoTags(text) {
    const tags = [];
    for (const [re, tag] of TAG_RULES) { if (re.test(text)) tags.push(tag); }
    return [...new Set(tags)];
  }

  function classifyContent(text) {
    const t = text.toLowerCase();
    if (/\b(?:tutorial|step[- ]by[- ]step|how to|walkthrough|guide)\b/.test(t)) return "tutorial";
    if (/\b(?:benchmark|comparison|vs\.|compared|evaluation)\b/.test(t)) return "comparison";
    if (/\b(?:tip|trick|protip|pro tip|hack|shortcut)\b/.test(t)) return "tip";
    if (/\b(?:workflow|process|pipeline|methodology|framework)\b/.test(t)) return "workflow";
    if (/\b(?:release|announce|launch|ship|update|changelog|new feature)\b/.test(t)) return "announcement";
    if (/\b(?:bug|fix|issue|error|problem|debug|troubleshoot)\b/.test(t)) return "troubleshooting";
    if (/\b(?:opinion|think|believe|hot take|unpopular|controversial)\b/.test(t)) return "opinion";
    if (/\b(?:config|setup|install|configuration)\b/.test(t)) return "configuration";
    if (text.length > 800) return "deep-dive";
    return "general";
  }

  // ── Platform Extractors ─────────────────────────────────────────────────
  const EX = {
    linkedin: {
      single(c) {
        const r = c || document;
        const sels = [".feed-shared-text", ".feed-shared-inline-show-more-text", ".update-components-text", ".feed-shared-update-v2__description", ".break-words"];
        let textEl = null;
        for (const s of sels) { textEl = r.querySelector(s); if (textEl && txt(textEl).length > 10) break; }
        const text = txt(textEl);
        const author = txt(r.querySelector(".feed-shared-actor__name, .update-components-actor__name, h1.text-heading-xlarge")).split("\n")[0];
        const likes = parseNum(txt(r.querySelector(".social-details-social-counts__reactions-count")));
        const comments = parseNum(txt(r.querySelector("button[aria-label*='comment']")));
        const reposts = parseNum(txt(r.querySelector("button[aria-label*='repost']")));
        let scope = c;
        if (!scope && textEl) scope = textEl.closest(".feed-shared-update-v2") || textEl.closest(".occludable-update") || textEl.closest("article") || textEl.parentElement;
        const ok = scope && scope !== document.body && scope !== document.documentElement;
        let articleUrl = "";
        const articleLink = (ok ? scope : r).querySelector("a.feed-shared-article__subtitle-link, a[data-tracking-control-name='article-link'], a.app-aware-link[href*='linkedin.com/pulse']");
        if (articleLink) articleUrl = articleLink.href;
        return { text, author, likes, comments, reposts, media: ok ? collectImgs(scope) : [], scope: ok ? scope : null, articleUrl, time: txt(r.querySelector(".feed-shared-actor__sub-description span, time")), conf: text.length > 100 ? 0.9 : text.length > 30 ? 0.6 : 0.2 };
      },
      multi() {
        return [...document.querySelectorAll(".feed-shared-update-v2, .occludable-update, [data-urn*='activity']")].filter(p => {
          const t = p.querySelector(".feed-shared-text, .update-components-text, .break-words");
          return t && txt(t).length > 20;
        });
      }
    },
    x: {
      single(c) {
        const r = c || document;
        const text = txt(r.querySelector('[data-testid="tweetText"]'));
        let author = "";
        const ue = r.querySelector('[data-testid="User-Name"]');
        if (ue) for (const s of ue.querySelectorAll("span")) { const t = s.innerText.trim(); if (t && !t.startsWith("@") && t.length > 1) { author = t; break; } }
        let likes = 0, comments = 0, reposts = 0;
        const mb = r.querySelector('[role="group"][aria-label]');
        if (mb) { const l = mb.getAttribute("aria-label") || ""; const m1 = l.match(/(\d[\d,]*)\s*repl/i), m2 = l.match(/(\d[\d,]*)\s*re(?:post|tweet)/i), m3 = l.match(/(\d[\d,]*)\s*like/i); if (m1) comments = parseNum(m1[1]); if (m2) reposts = parseNum(m2[1]); if (m3) likes = parseNum(m3[1]); }
        const a = c || (r.querySelector('[data-testid="tweetText"]') || {}).closest?.("article");
        return { text, author, likes, comments, reposts, media: collectImgs(a || r), scope: a || null, articleUrl: "", time: txt(r.querySelector("time")), conf: text.length > 30 ? 0.95 : 0.3 };
      },
      multi() { return [...document.querySelectorAll("article")].filter(a => a.querySelector('[data-testid="tweetText"]')); }
    },
    github: {
      single() {
        const el = document.querySelector(".markdown-body"); const text = txt(el);
        let author = txt(document.querySelector("[itemprop='author'] a, a[data-hovercard-type='user']"));
        if (!author) { const p = location.pathname.split("/").filter(Boolean); if (p.length) author = p[0]; }
        return { text, author, likes: parseNum(txt(document.querySelector("#repo-stars-counter-star"))), comments: 0, reposts: 0, media: collectImgs(el), scope: el, articleUrl: "", time: "", conf: text.length > 50 ? 0.9 : 0.3 };
      },
      multi() { return []; }
    },
    youtube: {
      single() {
        const el = document.querySelector("#description-inline-expander, #description"); const text = txt(el);
        return { text, author: txt(document.querySelector("#channel-name a, ytd-channel-name a")), likes: 0, comments: 0, reposts: 0, media: [], scope: el, articleUrl: "", time: "", conf: text.length > 30 ? 0.85 : 0.3 };
      },
      multi() { return []; }
    },
    hackernews: {
      single() {
        const title = txt(document.querySelector(".titleline a")); const body = txt(document.querySelector(".commtext")) || "";
        return { text: title + (body ? "\n\n" + body : ""), author: txt(document.querySelector(".hnuser")), likes: parseNum(txt(document.querySelector(".score"))), comments: 0, reposts: 0, media: [], scope: null, articleUrl: "", time: "", conf: title.length > 5 ? 0.8 : 0.2 };
      },
      multi() { return [...document.querySelectorAll(".athing")].slice(0, 30); }
    },
    reddit: {
      single() {
        const el = document.querySelector('[data-test-id="post-content"], shreddit-post, .Post'); const text = txt(el);
        return { text, author: txt(document.querySelector('a[href*="/user/"]')), likes: parseNum(document.querySelector("shreddit-post")?.getAttribute("score") || ""), comments: 0, reposts: 0, media: collectImgs(el), scope: el, articleUrl: "", time: "", conf: text.length > 20 ? 0.85 : 0.3 };
      },
      multi() { return []; }
    },
    blog: {
      single() {
        let el = document.querySelector("article, [role='main'], .post-content, .entry-content, .prose, main");
        if (!el) { let best = null, bLen = 0; for (const d of document.querySelectorAll("div, section")) { const l = d.innerText.length; if (l > bLen && l > 200) { best = d; bLen = l; } } el = best; }
        const text = txt(el);
        return { text, author: txt(document.querySelector("[rel='author'], .author, .byline")), likes: 0, comments: 0, reposts: 0, media: collectImgs(el), scope: el, articleUrl: "", time: "", conf: text.length > 100 ? 0.7 : 0.3 };
      },
      multi() { return []; }
    }
  };

  function extract(platform, container) {
    const ex = EX[platform] || EX.blog;
    const d = ex.single(container);
    const links = collectLinks(d.scope, d.text);
    const contentType = classifyContent(d.text);
    if (d.articleUrl && !links.find(l => l.url === d.articleUrl)) {
      links.unshift({ url: d.articleUrl, type: "article", label: "Shared article", weight: 0.95, source: "dom" });
    }
    return {
      id: platform + "-" + hashStr((d.text || "").slice(0, 200) + location.href),
      author: d.author || "", platform, url: location.href,
      time_relative: d.time || "", scraped_date: new Date().toISOString(),
      text: d.text || "", content_type: contentType,
      likes: d.likes || 0, comments: d.comments || 0, reposts: d.reposts || 0,
      media: d.media || [], links, tags: autoTags(d.text || ""),
      _conf: d.conf || 0.5
    };
  }

  function extractAll(platform) {
    const ex = EX[platform] || EX.blog;
    return ex.multi().map(c => extract(platform, c)).filter(d => d.text.length > 20);
  }

  // ── AI Refinement ─────────────────────────────────────────────────────────

  function aiRefine(data, callback) {
    const apiKey = getS("anthropic_key", "");
    if (!apiKey) { callback(null, "No API key — set it in Settings"); return; }

    const prompt = `You are a knowledge curation assistant for the Claude Expertise Vault — a database of expert knowledge about Claude Code, AI coding agents, and agentic programming.

Analyze this scraped post and return a refined JSON object. Your job:
1. Clean up the text: remove artifacts, fix formatting, preserve original meaning
2. Write a concise 1-2 sentence "summary" capturing the key insight
3. Extract "key_insights" — array of 3-5 actionable takeaways (short strings)
4. Improve "tags" — accurate taxonomy tags from: claude-code, agent-swarms, local-ai, hardware, benchmarks, coding-agents, context-management, model-comparison, security, devops, open-source, worktree-isolation, token-optimization, kv-cache-management, quantization, self-improving-agents, headless-dev, context-engineering, agent-hierarchy, prompt-engineering, fine-tuning, rag, tool-use, mcp, hooks, cursor, copilot, vllm, dspy
5. Classify "content_type": tutorial, comparison, tip, workflow, announcement, troubleshooting, opinion, configuration, deep-dive, general
6. Assess "expertise_level": beginner, intermediate, advanced, expert
7. Identify "resources" — each with {name, url, type} where type is: tool, library, framework, model, platform, service, paper, video
8. Rate "relevance" 0.0-1.0 for how relevant this is to Claude Code / agentic programming

Return ONLY valid JSON: {summary, key_insights, tags, content_type, expertise_level, resources, relevance, cleaned_text}

Input:
Platform: ${data.platform}
Author: ${data.author}
URL: ${data.url}
Content type (auto): ${data.content_type}
Tags (auto): ${data.tags.join(", ")}
Links found: ${data.links.map(l => l.url + " [" + l.type + "]").join(", ")}
Text:
${(data.text || "").slice(0, 4000)}`;

    GM_xmlhttpRequest({
      method: "POST",
      url: ANTHROPIC_API,
      headers: {
        "Content-Type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01",
        "anthropic-dangerous-direct-browser-access": "true"
      },
      data: JSON.stringify({
        model: "claude-haiku-4-5-20251001",
        max_tokens: 1500,
        messages: [{ role: "user", content: prompt }]
      }),
      onload(r) {
        if (r.status >= 300) { callback(null, "API " + r.status); return; }
        try {
          const resp = JSON.parse(r.responseText);
          const text = resp.content[0].text;
          const jsonStr = text.replace(/^```(?:json)?\s*/m, "").replace(/\s*```\s*$/m, "").trim();
          callback(JSON.parse(jsonStr), null);
        } catch (e) { callback(null, "Parse error: " + e.message); }
      },
      onerror() { callback(null, "Connection failed"); }
    });
  }

  // ── UI State ──────────────────────────────────────────────────────────────

  let fabBtn = null;
  let panelHost = null;   // outer fixed-position container
  let panelRoot = null;   // shadow root for style isolation
  let visible = false;
  let curData = null;
  let refinedData = null;

  // ── Init ──────────────────────────────────────────────────────────────────

  function init() {
    if (window.self !== window.top) return;
    if (document.body && document.body.innerText.length < 50) return;

    fabBtn = document.createElement("div");
    fabBtn.setAttribute("style", "position:fixed !important; bottom:24px !important; right:24px !important; width:48px !important; height:48px !important; z-index:2147483647 !important; background:#7c3aed !important; border-radius:14px !important; cursor:pointer !important; display:flex !important; align-items:center !important; justify-content:center !important; box-shadow:0 4px 20px rgba(124,58,237,0.5) !important; transition:transform 0.15s !important; font-family:system-ui,sans-serif !important; color:white !important; font-size:12px !important; font-weight:700 !important; letter-spacing:0.5px !important; user-select:none !important; line-height:1 !important; padding:0 !important; margin:0 !important; border:none !important;");
    fabBtn.textContent = "CE";
    fabBtn.title = "Claude Expertise (Ctrl+Shift+E)";
    fabBtn.addEventListener("mouseenter", () => { fabBtn.style.transform = "scale(1.08)"; });
    fabBtn.addEventListener("mouseleave", () => { fabBtn.style.transform = "scale(1)"; });
    fabBtn.addEventListener("click", toggle);

    const platform = detectPlatform();
    try {
      const multi = (EX[platform] || EX.blog).multi();
      if (multi.length > 1) {
        const badge = document.createElement("span");
        badge.setAttribute("style", "position:absolute !important; top:-5px !important; right:-5px !important; background:#ef4444 !important; color:white !important; font-size:10px !important; font-weight:700 !important; min-width:18px !important; height:18px !important; border-radius:9px !important; display:flex !important; align-items:center !important; justify-content:center !important; padding:0 4px !important; font-family:system-ui !important;");
        badge.textContent = multi.length;
        fabBtn.appendChild(badge);
      }
    } catch {}

    document.body.appendChild(fabBtn);

    document.addEventListener("keydown", e => {
      if (e.ctrlKey && e.shiftKey && e.key === "E") { e.preventDefault(); toggle(); }
    });

    // Health check on load + periodic
    checkServerHealth();
    setInterval(checkServerHealth, 60000);
  }

  // ── Panel Management (Shadow DOM) ────────────────────────────────────────
  // Shadow DOM bypasses all CSP restrictions — no iframe, no blob:, no srcdoc.
  // Styles are fully isolated from the host page.

  const PANEL_BASE = "position:fixed !important; bottom:80px !important; right:24px !important; width:460px !important; border:none !important; border-radius:16px !important; z-index:2147483647 !important; box-shadow:0 20px 60px rgba(0,0,0,0.6),0 0 0 1px rgba(124,58,237,0.3) !important; background:#0f0f1a !important; overflow:hidden !important;";

  function setPanelHeight(h) {
    panelHost.setAttribute("style", PANEL_BASE + " height:" + h + "px !important; max-height:75vh !important; opacity:1 !important; pointer-events:auto !important;");
  }

  function toggle() { visible ? hide() : show(); }

  function hide() {
    visible = false;
    if (panelHost && panelHost.parentNode) panelHost.parentNode.removeChild(panelHost);
    panelHost = null;
    panelRoot = null;
  }

  function show() {
    visible = true;
    refinedData = null;
    const platform = detectPlatform();
    curData = extract(platform);
    const multiCount = (EX[platform] || EX.blog).multi().length;
    renderPreview(curData, platform, multiCount);
  }

  // Render HTML into a Shadow DOM panel and bind actions immediately.
  // CSS is injected via CSSStyleSheet.replaceSync (completely CSP/Trusted-Types immune).
  // Body content is parsed via DOMParser and cloned via importNode (avoids adoptNode
  // cross-document transfer failures in restrictive CSP environments like LinkedIn).
  function writeIframe(html, height, bindFn) {
    if (panelHost && panelHost.parentNode) panelHost.parentNode.removeChild(panelHost);
    panelHost = document.createElement("div");
    panelHost.id = "cev-panel-host";
    setPanelHeight(height);
    panelRoot = panelHost.attachShadow({ mode: "open" });

    // 1. Inject CSS directly (NOT from parsed doc) — immune to all CSP/Trusted Types
    try {
      var sheet = new CSSStyleSheet();
      sheet.replaceSync(CSS);
      panelRoot.adoptedStyleSheets = [sheet];
    } catch (_e) {
      var styleEl = document.createElement("style");
      styleEl.textContent = CSS;
      panelRoot.appendChild(styleEl);
    }

    // 2. Extract body HTML and parse it via DOMParser
    var bodyMatch = html.match(/<body[^>]*>([\s\S]*)<\/body>/i);
    var bodyHtml = bodyMatch ? bodyMatch[1] : html;
    var parser = new DOMParser();
    var parsed = parser.parseFromString("<html><body>" + bodyHtml + "</body></html>", "text/html");

    // 3. Clone body children into wrapper via importNode (not adoptNode)
    var wrapper = document.createElement("div");
    wrapper.className = "cev-panel-inner";
    var children = Array.from(parsed.body.childNodes);
    for (var i = 0; i < children.length; i++) {
      wrapper.appendChild(document.importNode(children[i], true));
    }
    panelRoot.appendChild(wrapper);

    document.body.appendChild(panelHost);
    visible = true;
    if (bindFn) bindFn(panelRoot);
  }

  // Show a toast inside the shadow DOM panel
  function showToast(msg, type) {
    try {
      if (!panelRoot) return;
      const t = panelRoot.getElementById("toast");
      if (!t) return;
      t.textContent = msg;
      t.className = "toast " + type;
      setTimeout(() => { t.classList.add("show"); }, 10);
      setTimeout(() => { t.classList.remove("show"); }, 2500);
    } catch {}
  }

  // Helper: read form values from shadow root
  function readField(root, id) {
    const el = root.getElementById(id);
    return el ? el.value.trim() : "";
  }

  function readForm(root) {
    return {
      platform: readField(root, "f-platform"),
      author: readField(root, "f-author"),
      likes: readField(root, "f-likes"),
      comments: readField(root, "f-comments"),
      reposts: readField(root, "f-reposts"),
      tags: readField(root, "f-tags"),
      text: readField(root, "f-text"),
      media: readField(root, "f-media"),
      url: readField(root, "f-url"),
    };
  }

  // Helper: bind click to a data-action attribute
  function bindActions(root, handlers) {
    root.querySelectorAll("[data-action]").forEach(el => {
      const action = el.getAttribute("data-action");
      if (handlers[action]) {
        el.addEventListener("click", e => {
          e.preventDefault();
          handlers[action](root, el);
        });
      }
    });
  }

  // ── CSS (shared across all panels) ────────────────────────────────────────

  const CSS = `*{box-sizing:border-box;margin:0;padding:0}
:host{display:block;overflow:hidden;border-radius:16px;height:100%;width:100%}
.cev-panel-inner{background:#0f0f1a;color:#e2e2f0;font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;overflow:hidden;display:flex;flex-direction:column;height:100%}
.hdr{display:flex;align-items:center;justify-content:space-between;padding:12px 16px;background:#151528;border-bottom:1px solid #2a2a45}
.hdr-left{display:flex;align-items:center;gap:10px}
.hdr-icon{width:32px;height:32px;border-radius:8px;background:linear-gradient(135deg,#7c3aed,#a855f7);display:flex;align-items:center;justify-content:center;color:#fff;font-size:11px;font-weight:800;flex-shrink:0}
.hdr-icon.spin{animation:spin 1.5s linear infinite}
@keyframes spin{0%{transform:rotate(0)}100%{transform:rotate(360deg)}}
.hdr-title{font-size:14px;font-weight:600;color:#f0f0ff}
.hdr-sub{font-size:11px;color:#888aaa}
.hdr-right{display:flex;gap:4px}
.hdr-right button{background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.1);border-radius:8px;color:#aaa;cursor:pointer;padding:4px 10px;font-size:11px;font-family:inherit}
.hdr-right button:hover{background:rgba(255,255,255,0.12);color:#fff}
.conf{display:flex;align-items:center;gap:8px;padding:6px 16px;background:#12122a;font-size:11px;color:#888aaa}
.conf-bar{flex:1;height:3px;background:#1e1e38;border-radius:2px;overflow:hidden}
.conf-fill{height:100%;border-radius:2px}
.tag-mini{background:#1e1e38;padding:2px 6px;border-radius:4px;font-size:10px}
.body{padding:12px 16px;overflow-y:auto;flex:1}
.field{margin-bottom:10px}
.field:last-child{margin-bottom:0}
.field label{display:block;font-size:10px;font-weight:600;color:#7c7ca0;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:3px}
.field input,.field textarea,.field select{width:100%;background:#0a0a16;border:1px solid #2a2a45;border-radius:6px;color:#e2e2f0;padding:6px 10px;font-size:12px;font-family:inherit;outline:none}
.field input:focus,.field textarea:focus,.field select:focus{border-color:#7c3aed;box-shadow:0 0 0 2px rgba(124,58,237,0.15)}
.field textarea{resize:vertical;min-height:60px;font-family:"SF Mono","Fira Code",Consolas,monospace;font-size:11px;line-height:1.5}
.field select{cursor:pointer}
.hint{font-size:9px;color:#555578;margin-top:2px}
.row{display:flex;gap:8px}
.row .field{flex:1}
.link-list{max-height:120px;overflow-y:auto;border:1px solid #2a2a45;border-radius:6px;background:#0a0a16}
.link-row{display:flex;align-items:center;gap:6px;padding:4px 8px;border-bottom:1px solid #1a1a30;font-size:11px}
.link-row:last-child{border-bottom:none}
.link-badge{font-size:9px;font-weight:700;width:28px;text-align:center;flex-shrink:0}
.link-url{flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:#a0a0cc}
.link-type{font-size:9px;color:#666;background:#1a1a30;padding:1px 5px;border-radius:3px}
.rf-section{padding:10px 16px;background:#0d0d20;border-bottom:1px solid #2a2a45}
.rf-label{font-size:10px;font-weight:700;color:#7c3aed;text-transform:uppercase;letter-spacing:0.5px;margin:6px 0 3px}
.rf-text{font-size:12px;color:#c0c0e0;line-height:1.5}
.rf-list{padding-left:16px;font-size:11px;color:#a0a0cc}
.rf-list li{margin:2px 0}
.rf-meta{display:flex;gap:12px;font-size:11px;color:#888aaa;margin-top:4px}
.rf-resources{display:flex;flex-wrap:wrap;gap:4px;margin-top:2px}
.rf-res{font-size:10px;background:#1a1a38;color:#a0a0cc;padding:2px 6px;border-radius:4px}
.rf-res small{color:#666;margin-left:2px}
.ftr{padding:10px 16px;border-top:1px solid #2a2a45;display:flex;gap:6px;background:#111124}
.btn{flex:1;padding:8px 12px;border:none;border-radius:8px;cursor:pointer;font-size:12px;font-weight:600;font-family:inherit;transition:background 0.15s}
.btn:active{transform:scale(0.97)}
.btn:disabled{opacity:0.5;cursor:default}
.pri{background:#7c3aed;color:#fff}
.pri:hover:not(:disabled){background:#8b5cf6}
.sec{background:rgba(255,255,255,0.08);color:#c0c0e0;border:1px solid rgba(255,255,255,0.1)}
.sec:hover{background:rgba(255,255,255,0.14)}
.accent{background:linear-gradient(135deg,#0ea5e9,#7c3aed);color:#fff}
.accent:hover:not(:disabled){opacity:0.9}
.toast{position:fixed;bottom:12px;left:50%;transform:translateX(-50%) translateY(10px);background:#1e1e38;color:#e2e2f0;padding:6px 16px;border-radius:8px;font-size:12px;box-shadow:0 4px 20px rgba(0,0,0,0.5);opacity:0;transition:opacity 0.2s,transform 0.2s;pointer-events:none;white-space:nowrap}
.toast.show{opacity:1;transform:translateX(-50%) translateY(0)}
.toast.ok{border-left:4px solid #22c55e}
.toast.err{border-left:4px solid #ef4444}
.bact{display:flex;gap:6px;margin-bottom:8px}
.bact button{background:rgba(255,255,255,0.06);border:1px solid rgba(255,255,255,0.1);border-radius:6px;color:#888;cursor:pointer;padding:3px 10px;font-size:10px;font-family:inherit}
.bact button:hover{color:#fff;background:rgba(255,255,255,0.1)}
.blist{max-height:240px;overflow-y:auto;border:1px solid #2a2a45;border-radius:8px;background:#0a0a16}
.bitem{display:flex;align-items:flex-start;gap:8px;padding:8px 10px;border-bottom:1px solid #1e1e38;cursor:pointer}
.bitem:last-child{border-bottom:none}
.bitem:hover{background:#151530}
.bitem input{margin-top:3px;accent-color:#7c3aed;width:14px;height:14px;flex-shrink:0}
.btxt{flex:1;font-size:11px;line-height:1.4;color:#9999bb}
.btxt b{color:#c0c0e8;display:block;margin-bottom:1px;font-size:12px}
.btags{display:block;font-size:9px;color:#666;margin-bottom:2px}
.spinner{width:32px;height:32px;border:3px solid #2a2a45;border-top-color:#7c3aed;border-radius:50%;animation:spin 0.8s linear infinite}`;

  function buildHtml(body) {
    return "<!DOCTYPE html><html><head><meta charset=\"utf-8\"><style>" + CSS + "</style></head><body>" + body + "<div class=\"toast\" id=\"toast\"></div></body></html>";
  }

  // ── Render: Preview ─────────────────────────────────────────────────────

  function renderPreview(data, platform, multiCount) {
    const c = data._conf;
    const pct = Math.round(c * 100);
    const cLabel = c >= 0.8 ? "High" : c >= 0.5 ? "Med" : "Low";
    const cColor = c >= 0.8 ? "#22c55e" : c >= 0.5 ? "#eab308" : "#ef4444";

    const linkRows = data.links.slice(0, 8).map(l => {
      const icon = { "github-repo": "GH", "github-thread": "GH", paper: "Ac", package: "Pkg", documentation: "Doc", video: "Vid", model: "ML", article: "Art", discussion: "Dsc", document: "PDF" }[l.type] || "Lnk";
      const color = { "github-repo": "#f0883e", paper: "#22c55e", package: "#3b82f6", model: "#a855f7", video: "#ef4444" }[l.type] || "#888";
      const label = esc(l.label || l.url.replace(/^https?:\/\/(www\.)?/, "").slice(0, 50));
      return '<div class="link-row"><span class="link-badge" style="color:' + color + '">' + icon + '</span><span class="link-url" title="' + esc(l.url) + '">' + label + '</span><span class="link-type">' + l.type + '</span></div>';
    }).join("");

    const rfSection = refinedData ? (
      '<div class="rf-section">' +
      '<div class="rf-label">AI Summary</div><div class="rf-text">' + esc(refinedData.summary) + '</div>' +
      (refinedData.key_insights ? '<div class="rf-label">Key Insights</div><ul class="rf-list">' + refinedData.key_insights.map(i => '<li>' + esc(i) + '</li>').join("") + '</ul>' : "") +
      (refinedData.expertise_level ? '<div class="rf-meta"><span>Level: ' + esc(refinedData.expertise_level) + '</span><span>Relevance: ' + Math.round((refinedData.relevance || 0) * 100) + '%</span></div>' : "") +
      (refinedData.resources && refinedData.resources.length ? '<div class="rf-label">Resources</div><div class="rf-resources">' + refinedData.resources.map(r => '<span class="rf-res" title="' + esc(r.url || "") + '">' + esc(r.name) + ' <small>' + esc(r.type) + '</small></span>').join("") + '</div>' : "") +
      '</div>'
    ) : "";

    const hasKey = !!getS("anthropic_key", "");
    const refineBtn = hasKey
      ? (refinedData ? '<button class="btn accent" disabled>Refined</button>' : '<button class="btn accent" data-action="refine">Refine with AI</button>')
      : "";

    const html = buildHtml(
      '<div class="hdr"><div class="hdr-left"><div class="hdr-icon">CE</div><div><div class="hdr-title">Claude Expertise</div><div class="hdr-sub">' + esc(data.content_type) + ' / ' + esc(platform) + '</div></div></div><div class="hdr-right">' +
      (multiCount > 1 ? '<button data-action="batch">Batch (' + multiCount + ')</button>' : '') +
      '<button data-action="settings">Cfg</button><button data-action="close">X</button></div></div>' +
      '<div class="conf"><span>' + cLabel + ' ' + pct + '%</span><div class="conf-bar"><div class="conf-fill" style="width:' + pct + '%;background:' + cColor + '"></div></div><span class="tag-mini">' + data.tags.length + ' tags</span><span class="tag-mini">' + data.links.length + ' links</span></div>' +
      rfSection +
      '<div class="body">' +
      '<div class="row"><div class="field"><label>Author</label><input id="f-author" value="' + esc(data.author) + '"/></div><div class="field" style="max-width:100px"><label>Platform</label><select id="f-platform">' + ["linkedin", "x", "github", "youtube", "hackernews", "reddit", "blog", "other"].map(p => '<option value="' + p + '"' + (p === data.platform ? ' selected' : '') + '>' + p + '</option>').join("") + '</select></div></div>' +
      '<div class="row"><div class="field"><label>Likes</label><input id="f-likes" type="number" value="' + data.likes + '"/></div><div class="field"><label>Comments</label><input id="f-comments" type="number" value="' + data.comments + '"/></div><div class="field"><label>Reposts</label><input id="f-reposts" type="number" value="' + data.reposts + '"/></div></div>' +
      '<div class="field"><label>Tags</label><input id="f-tags" value="' + esc((refinedData ? refinedData.tags : data.tags).join(", ")) + '"/><div class="hint">Comma-separated taxonomy tags</div></div>' +
      '<div class="field"><label>Content (' + data.text.length + ' chars)</label><textarea id="f-text" rows="5">' + esc(refinedData ? refinedData.cleaned_text || data.text : data.text) + '</textarea></div>' +
      (data.links.length ? '<div class="field"><label>Links (' + data.links.length + ')</label><div class="link-list">' + linkRows + '</div></div>' : '') +
      '<div class="field"><label>Media (' + data.media.length + ')</label><textarea id="f-media" rows="2">' + esc(data.media.join("\n")) + '</textarea></div>' +
      '<div class="field"><label>Page URL</label><input id="f-url" value="' + esc(data.url) + '" readonly/></div>' +
      '</div>' +
      '<div class="ftr">' + refineBtn + '<button class="btn sec" data-action="copy">Copy JSONL</button><button class="btn pri" data-action="send">Send to API</button></div>'
    );

    writeIframe(html, 600, function (doc) {
      bindActions(doc, {
        close: function () { hide(); },
        settings: function () { renderSettings(); },
        batch: function () { renderBatch(detectPlatform()); },
        refine: function () { doRefine(); },
        copy: function (d) {
          const j = buildExport(readForm(d));
          clipCopy(JSON.stringify(j));
          showToast("JSONL copied to clipboard", "ok");
        },
        send: function (d) {
          const j = buildExport(readForm(d));
          apiSend([j]);
        },
      });
    });
  }

  // ── Render: Settings ────────────────────────────────────────────────────

  function renderSettings() {
    const html = buildHtml(
      '<div class="hdr"><div class="hdr-left"><div class="hdr-icon">CE</div><div><div class="hdr-title">Settings</div><div class="hdr-sub">Configure export + AI</div></div></div><div class="hdr-right"><button data-action="back">Back</button><button data-action="close">X</button></div></div>' +
      '<div class="body">' +
      '<div class="field"><label>Server URL</label><input id="s-server" value="' + esc(getS("server_url", DEFAULT_SERVER)) + '"/><div class="hint">Base URL of your Expertise Vault server (e.g. http://localhost:8645)</div></div>' +
      '<div class="field"><label>Ingest API Endpoint</label><input id="s-api" value="' + esc(getS("api_url", DEFAULT_INGEST_API)) + '"/><div class="hint">POST endpoint for ingesting scraped data</div></div>' +
      '<div class="field"><label>Anthropic API Key</label><input id="s-aikey" type="password" value="' + esc(getS("anthropic_key", "")) + '"/><div class="hint">For AI refinement (claude-haiku-4-5, ~$0.001/refine). Leave blank to disable.</div></div>' +
      '<div class="field"><label>Default Author Override</label><input id="s-author" value="' + esc(getS("default_author", "")) + '"/><div class="hint">Overrides extracted author on every export</div></div>' +
      '<div class="field"><label>Extra Tags</label><input id="s-tags" value="' + esc(getS("extra_tags", "")) + '"/><div class="hint">Comma-separated, always appended to every export</div></div>' +
      '<div style="padding:8px 0;font-size:11px;color:#888aaa;text-align:center">Server: ' + (serverOnline ? '<span style="color:#22c55e">Online</span>' : '<span style="color:#ef4444">Offline</span>') + ' | v4.0.0</div>' +
      '</div>' +
      '<div class="ftr"><button class="btn sec" data-action="test">Test Connection</button><button class="btn pri" data-action="save">Save Settings</button></div>'
    );

    writeIframe(html, 420, function (doc) {
      bindActions(doc, {
        close: function () { hide(); },
        back: function () { show(); },
        test: function () {
          showToast("Testing connection...", "ok");
          checkServerHealth();
          setTimeout(function () { showToast(serverOnline ? "Server online" : "Server offline", serverOnline ? "ok" : "err"); }, 1500);
        },
        save: function (d) {
          setS("server_url", readField(d, "s-server").replace(/\/+$/, ""));
          setS("api_url", readField(d, "s-api"));
          setS("anthropic_key", readField(d, "s-aikey"));
          setS("default_author", readField(d, "s-author"));
          setS("extra_tags", readField(d, "s-tags"));
          checkServerHealth();
          showToast("Settings saved", "ok");
          setTimeout(function () { show(); }, 600);
        },
      });
    });
  }

  // ── Render: Batch ───────────────────────────────────────────────────────

  function renderBatch(platform) {
    const items = extractAll(platform);

    const html = buildHtml(
      '<div class="hdr"><div class="hdr-left"><div class="hdr-icon">CE</div><div><div class="hdr-title">Batch Export</div><div class="hdr-sub">' + items.length + ' posts detected</div></div></div><div class="hdr-right"><button data-action="back">Back</button><button data-action="close">X</button></div></div>' +
      '<div class="body">' +
      '<div class="bact"><button data-action="selall">All</button><button data-action="selnone">None</button></div>' +
      '<div class="blist">' +
      items.map(function (d, i) {
        return '<label class="bitem"><input type="checkbox" data-i="' + i + '" checked/><div class="btxt"><b>' + esc(d.author || "Unknown") + '</b><span class="btags">' + d.tags.slice(0, 3).join(", ") + ' / ' + d.links.length + ' links</span>' + esc(d.text.slice(0, 80).replace(/\n/g, " ")) + (d.text.length > 80 ? "..." : "") + '</div></label>';
      }).join("") +
      '</div></div>' +
      '<div class="ftr"><button class="btn sec" data-action="bcopy">Copy All JSONL</button><button class="btn pri" data-action="bsend">Send All to API</button></div>'
    );

    writeIframe(html, 480, function (doc) {
      function getSelected() {
        const sel = [];
        doc.querySelectorAll(".blist input").forEach(function (cb) {
          if (cb.checked) sel.push(parseInt(cb.dataset.i));
        });
        return items.filter(function (_, i) { return sel.includes(i); });
      }

      bindActions(doc, {
        close: function () { hide(); },
        back: function () { show(); },
        selall: function (d) { d.querySelectorAll(".blist input").forEach(function (c) { c.checked = true; }); },
        selnone: function (d) { d.querySelectorAll(".blist input").forEach(function (c) { c.checked = false; }); },
        bcopy: function () {
          const sel = getSelected();
          if (!sel.length) { showToast("No posts selected", "err"); return; }
          const lines = sel.map(function (d) { const o = Object.assign({}, d); delete o._conf; return JSON.stringify(o); });
          clipCopy(lines.join("\n"));
          showToast(sel.length + " posts copied", "ok");
        },
        bsend: function (d) {
          const sel = getSelected();
          if (!sel.length) { showToast("No posts selected", "err"); return; }
          // Show progress bar
          let prog = d.querySelector(".cev-batch-progress");
          if (!prog) {
            prog = document.createElement("div");
            prog.className = "cev-batch-progress";
            prog.setAttribute("style", "margin:8px 20px;height:4px;border-radius:2px;background:#1e1e3a;overflow:hidden;");
            prog.innerHTML = '<div style="height:100%;width:0%;background:linear-gradient(90deg,#7c3aed,#a78bfa);border-radius:2px;transition:width 0.3s;"></div>';
            const ftr = d.querySelector(".ftr");
            if (ftr) ftr.parentNode.insertBefore(prog, ftr);
          }
          const bar = prog.querySelector("div");
          const total = sel.length;
          const BATCH = 5;
          let sent = 0;
          function sendBatch(start) {
            const batch = sel.slice(start, start + BATCH).map(function (dd) { const o = Object.assign({}, dd); delete o._conf; return o; });
            if (!batch.length) {
              bar.style.width = "100%";
              showToast("All " + total + " posts sent", "ok");
              return;
            }
            apiSend(batch);
            sent += batch.length;
            bar.style.width = Math.round(sent / total * 100) + "%";
            if (sent < total) setTimeout(function () { sendBatch(start + BATCH); }, 300);
          }
          sendBatch(0);
        },
      });
    });
  }

  // ── Render: Refining ────────────────────────────────────────────────────

  function renderRefining() {
    const html = buildHtml(
      '<div class="hdr"><div class="hdr-left"><div class="hdr-icon spin">CE</div><div><div class="hdr-title">Refining with AI...</div><div class="hdr-sub">Analyzing content, extracting insights</div></div></div><div class="hdr-right"><button data-action="close">X</button></div></div>' +
      '<div class="body" style="display:flex;align-items:center;justify-content:center;min-height:200px;flex-direction:column;gap:16px"><div class="spinner"></div><div style="color:#888aaa;font-size:13px;text-align:center">Sending to Claude Haiku for refinement...<br/>Extracting key insights, resources, and tags</div></div>'
    );

    writeIframe(html, 320, function (doc) {
      bindActions(doc, {
        close: function () { hide(); },
      });
    });
  }

  function doRefine() {
    if (!curData) return;
    renderRefining();
    aiRefine(curData, function (result, err) {
      if (err) {
        const platform = detectPlatform();
        const multiCount = (EX[platform] || EX.blog).multi().length;
        renderPreview(curData, platform, multiCount);
        setTimeout(function () { showToast("Refine failed: " + err, "err"); }, 300);
      } else {
        refinedData = result;
        if (result.tags) curData.tags = [...new Set([...result.tags])];
        if (result.content_type) curData.content_type = result.content_type;
        const platform = detectPlatform();
        const multiCount = (EX[platform] || EX.blog).multi().length;
        renderPreview(curData, platform, multiCount);
        setTimeout(function () { showToast("AI refinement complete", "ok"); }, 300);
      }
    });
  }

  // ── Export Builder ──────────────────────────────────────────────────────

  function buildExport(form) {
    const defAuthor = getS("default_author", "");
    const extraTags = (getS("extra_tags", "") || "").split(",").map(t => t.trim()).filter(Boolean);
    const formTags = (form.tags || "").split(",").map(t => t.trim()).filter(Boolean);
    const allTags = [...new Set([...formTags, ...extraTags])];
    const links = curData ? curData.links.map(l => ({ url: l.url, type: l.type, label: l.label })) : [];

    const obj = {
      id: form.platform + "-" + hashStr((form.text || "").slice(0, 200) + form.url),
      author: defAuthor || form.author || "",
      platform: form.platform,
      url: form.url,
      content_type: curData ? curData.content_type : "general",
      time_relative: curData ? curData.time_relative : "",
      scraped_date: new Date().toISOString(),
      text: form.text || "",
      likes: parseInt(form.likes, 10) || 0,
      comments: parseInt(form.comments, 10) || 0,
      reposts: parseInt(form.reposts, 10) || 0,
      media: (form.media || "").split("\n").map(u => u.trim()).filter(Boolean),
      links: links,
      tags: allTags,
    };

    if (refinedData) {
      obj.ai_refined = true;
      obj.summary = refinedData.summary || "";
      obj.key_insights = refinedData.key_insights || [];
      obj.expertise_level = refinedData.expertise_level || "";
      obj.relevance = refinedData.relevance || 0;
      if (refinedData.resources) obj.resources = refinedData.resources;
    }

    return obj;
  }

  // ── Clipboard + API ─────────────────────────────────────────────────────

  function clipCopy(text) {
    if (typeof GM_setClipboard === "function") {
      GM_setClipboard(text, "text");
    } else {
      navigator.clipboard.writeText(text).catch(function () {});
    }
  }

  function apiSend(posts) {
    const url = getS("api_url", getServerUrl() + "/api/ingest");
    const body = JSON.stringify({ posts: posts });
    if (typeof GM_xmlhttpRequest === "function") {
      GM_xmlhttpRequest({
        method: "POST", url: url, headers: { "Content-Type": "application/json" }, data: body,
        onload: function (r) {
          if (r.status < 300) {
            showToast("Sent " + posts.length + " post(s) to API", "ok");
            trackIngest(posts);
          } else {
            showToast("API error: " + r.status, "err");
          }
        },
        onerror: function () { showToast("Connection failed — is server running?", "err"); }
      });
    } else {
      fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: body })
        .then(function (r) {
          if (r.ok) { showToast("Sent " + posts.length + " post(s)", "ok"); trackIngest(posts); }
          else showToast("Error: " + r.status, "err");
        })
        .catch(function () { showToast("Connection failed", "err"); });
    }
  }

  // ── Boot ──────────────────────────────────────────────────────────────────
  if (document.readyState === "complete") setTimeout(init, 500);
  else window.addEventListener("load", function () { setTimeout(init, 500); });
})();

defmodule ExpertiseApiWeb.SearchLive do
  use ExpertiseApiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: send(self(), :load_linkedin_status)

    {:ok,
     socket
     |> assign(:query, "")
     |> assign(:results, [])
     |> assign(:searching, false)
     |> assign(:error, nil)
     |> assign(:page_title, "Claude Expertise Search")
     |> assign(:show_settings, false)
     |> assign(:linkedin_auth, nil)
     |> assign(:linkedin_loading, false)
     |> assign(:linkedin_error, nil)
     |> assign(:manual_cookies, "")}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) when byte_size(query) > 1 do
    send(self(), {:do_search, query})
    {:noreply, assign(socket, query: query, searching: true, error: nil)}
  end

  def handle_event("search", _params, socket) do
    {:noreply, assign(socket, results: [], error: nil, searching: false)}
  end

  def handle_event("toggle_settings", _params, socket) do
    show = !socket.assigns.show_settings
    if show, do: send(self(), :load_linkedin_status)
    {:noreply, assign(socket, show_settings: show)}
  end

  def handle_event("linkedin_playwright_auth", _params, socket) do
    send(self(), :linkedin_playwright_auth)
    {:noreply, assign(socket, linkedin_loading: true, linkedin_error: nil)}
  end

  def handle_event("linkedin_manual_auth", %{"cookies" => cookies}, socket)
      when byte_size(cookies) > 10 do
    send(self(), {:linkedin_manual_auth, cookies})
    {:noreply, assign(socket, linkedin_loading: true, linkedin_error: nil, manual_cookies: "")}
  end

  def handle_event("linkedin_manual_auth", _params, socket) do
    {:noreply, assign(socket, linkedin_error: "Paste your LinkedIn cookie string (li_at=... or full header)")}
  end

  def handle_event("linkedin_validate", _params, socket) do
    send(self(), :linkedin_validate)
    {:noreply, assign(socket, linkedin_loading: true, linkedin_error: nil)}
  end

  def handle_event("update_manual_cookies", %{"value" => value}, socket) do
    {:noreply, assign(socket, manual_cookies: value)}
  end

  @impl true
  def handle_info({:do_search, query}, socket) do
    case ExpertiseApi.Search.search(query, top_k: 10) do
      {:ok, results} ->
        {:noreply, assign(socket, results: results, searching: false, error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, results: [], searching: false, error: to_string(reason))}
    end
  end

  def handle_info(:load_linkedin_status, socket) do
    case ExpertiseApi.LinkedInAuth.status() do
      {:ok, data} -> {:noreply, assign(socket, linkedin_auth: data)}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_info(:linkedin_playwright_auth, socket) do
    result =
      case ExpertiseApi.LinkedInAuth.authenticate("playwright") do
        {:ok, data} -> assign(socket, linkedin_auth: data, linkedin_loading: false)
        {:error, reason} -> assign(socket, linkedin_loading: false, linkedin_error: reason)
      end

    {:noreply, result}
  end

  def handle_info({:linkedin_manual_auth, cookies}, socket) do
    result =
      case ExpertiseApi.LinkedInAuth.authenticate_manual(cookies) do
        {:ok, data} -> assign(socket, linkedin_auth: data, linkedin_loading: false)
        {:error, reason} -> assign(socket, linkedin_loading: false, linkedin_error: reason)
      end

    {:noreply, result}
  end

  def handle_info(:linkedin_validate, socket) do
    result =
      case ExpertiseApi.LinkedInAuth.validate() do
        {:ok, data} -> assign(socket, linkedin_auth: data, linkedin_loading: false)
        {:error, reason} -> assign(socket, linkedin_loading: false, linkedin_error: reason)
      end

    {:noreply, result}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      .glass-body {
        min-height: 100vh;
        background: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 50%, #16213e 100%);
        color: #e2e8f0;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      }
      .glass-card {
        backdrop-filter: blur(16px);
        -webkit-backdrop-filter: blur(16px);
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(255, 255, 255, 0.1);
        border-radius: 12px;
        transition: all 0.3s ease;
      }
      .glass-card:hover {
        background: rgba(255, 255, 255, 0.08);
        border-color: rgba(168, 85, 247, 0.3);
        box-shadow: 0 0 20px rgba(168, 85, 247, 0.1);
      }
      .glass-input {
        backdrop-filter: blur(12px);
        background: rgba(255, 255, 255, 0.06);
        border: 1px solid rgba(255, 255, 255, 0.12);
        border-radius: 10px;
        color: #e2e8f0;
        font-size: 1rem;
        padding: 12px 16px;
        width: 100%;
        outline: none;
        transition: all 0.3s ease;
      }
      .glass-input::placeholder { color: rgba(226, 232, 240, 0.4); }
      .glass-input:focus {
        border-color: rgba(168, 85, 247, 0.5);
        box-shadow: 0 0 0 3px rgba(168, 85, 247, 0.15);
        background: rgba(255, 255, 255, 0.08);
      }
      .glass-btn {
        backdrop-filter: blur(12px);
        background: rgba(168, 85, 247, 0.2);
        border: 1px solid rgba(168, 85, 247, 0.3);
        border-radius: 10px;
        color: #c4b5fd;
        font-weight: 600;
        padding: 12px 24px;
        cursor: pointer;
        transition: all 0.3s ease;
        font-size: 0.95rem;
      }
      .glass-btn:hover {
        background: rgba(168, 85, 247, 0.35);
        border-color: rgba(168, 85, 247, 0.5);
        color: #e9d5ff;
        box-shadow: 0 0 15px rgba(168, 85, 247, 0.2);
      }
      .glass-btn:disabled { opacity: 0.5; cursor: not-allowed; }
      .nav-pill {
        backdrop-filter: blur(12px);
        background: rgba(255, 255, 255, 0.05);
        border: 1px solid rgba(255, 255, 255, 0.08);
        border-radius: 20px;
        color: rgba(226, 232, 240, 0.7);
        padding: 6px 16px;
        font-size: 0.85rem;
        font-weight: 500;
        text-decoration: none;
        transition: all 0.3s ease;
        display: inline-block;
      }
      .nav-pill:hover {
        background: rgba(168, 85, 247, 0.15);
        border-color: rgba(168, 85, 247, 0.3);
        color: #c4b5fd;
      }
      .nav-pill.active {
        background: rgba(168, 85, 247, 0.2);
        border-color: rgba(168, 85, 247, 0.4);
        color: #e9d5ff;
      }
      .score-badge {
        background: rgba(168, 85, 247, 0.2);
        border: 1px solid rgba(168, 85, 247, 0.3);
        border-radius: 6px;
        color: #c4b5fd;
        font-size: 0.75rem;
        font-weight: 600;
        padding: 2px 8px;
      }
      @keyframes spin { to { transform: rotate(360deg); } }
      .glass-spinner {
        width: 32px; height: 32px;
        border: 3px solid rgba(168, 85, 247, 0.2);
        border-top-color: #a855f7;
        border-radius: 50%;
        animation: spin 0.8s linear infinite;
      }
      .text-accent { color: #a855f7; }
      .text-muted { color: rgba(226, 232, 240, 0.5); }
      .glass-error {
        backdrop-filter: blur(12px);
        background: rgba(239, 68, 68, 0.1);
        border: 1px solid rgba(239, 68, 68, 0.3);
        border-radius: 10px;
        color: #fca5a5;
        padding: 12px 16px;
      }
      .header-glow { text-shadow: 0 0 40px rgba(168, 85, 247, 0.3); }
    </style>

    <div class="glass-body">
      <div style="max-width: 800px; margin: 0 auto; padding: 48px 24px;">
        <div style="text-align: center; margin-bottom: 12px;">
          <h1 style="font-size: 2rem; font-weight: 700; margin: 0;" class="header-glow">
            <span class="text-accent">Claude</span> Expertise Vault
          </h1>
          <p class="text-muted" style="margin-top: 8px; font-size: 0.9rem;">
            Semantic search across expert knowledge
          </p>
        </div>

        <nav style="text-align: center; margin-bottom: 32px; display: flex; justify-content: center; gap: 8px;">
          <a href="/" class="nav-pill active">Search</a>
          <a href="/docs" class="nav-pill">API Docs</a>
          <a href="/api/stats" target="_blank" rel="noopener" class="nav-pill">Stats</a>
          <button phx-click="toggle_settings" class={"nav-pill" <> if(@show_settings, do: " active", else: "")} style="border: none; cursor: pointer;">
            ⚙ Settings
          </button>
        </nav>

        <%= if @show_settings do %>
        <div class="glass-card" style="padding: 24px; margin-bottom: 32px;">
          <h3 style="margin: 0 0 16px 0; font-size: 1.1rem; font-weight: 600;">
            <span style="margin-right: 8px;">🔗</span>LinkedIn Authentication
          </h3>

          <%!-- Status display --%>
          <div style="display: flex; align-items: center; gap: 12px; margin-bottom: 16px; padding: 12px; border-radius: 8px; background: rgba(255,255,255,0.03);">
            <%= if @linkedin_auth && @linkedin_auth["valid"] do %>
              <div style="width: 10px; height: 10px; border-radius: 50%; background: #4ade80; box-shadow: 0 0 8px rgba(74,222,128,0.4);"></div>
              <div>
                <div style="font-weight: 500; color: #e2e8f0;">Authenticated</div>
                <div class="text-muted" style="font-size: 0.8rem;">
                  via <%= @linkedin_auth["method"] || "unknown" %>
                  <%= if @linkedin_auth["cookie_count"] do %>
                    · <%= @linkedin_auth["cookie_count"] %> cookies
                  <% end %>
                  <%= if @linkedin_auth["li_at_expires"] do %>
                    · expires <%= @linkedin_auth["li_at_expires"] %>
                  <% end %>
                </div>
                <%= if @linkedin_auth["last_validated"] do %>
                  <div class="text-muted" style="font-size: 0.75rem; margin-top: 2px;">
                    Last validated: <%= @linkedin_auth["last_validated"] %>
                  </div>
                <% end %>
              </div>
            <% else %>
              <div style={"width: 10px; height: 10px; border-radius: 50%; background: " <> if(@linkedin_auth && @linkedin_auth["status"] == "expired", do: "#fb923c", else: "#6b7280") <> ";"}></div>
              <div>
                <div style="font-weight: 500; color: #e2e8f0;">
                  <%= if @linkedin_auth && @linkedin_auth["status"] == "expired", do: "Session Expired", else: "Not Authenticated" %>
                </div>
                <div class="text-muted" style="font-size: 0.8rem;">
                  LinkedIn cookie authentication required for profile scraping
                </div>
              </div>
            <% end %>
          </div>

          <%!-- Error display --%>
          <%= if @linkedin_error do %>
            <div class="glass-error" style="margin-bottom: 16px; font-size: 0.85rem;">
              <%= @linkedin_error %>
            </div>
          <% end %>

          <%!-- Auth methods --%>
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
            <%!-- Method 1: Playwright browser --%>
            <div style="padding: 16px; border-radius: 10px; background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.06);">
              <div style="font-weight: 600; font-size: 0.9rem; margin-bottom: 6px;">🌐 Browser Login</div>
              <p class="text-muted" style="font-size: 0.78rem; margin: 0 0 12px 0;">
                Opens a Playwright browser window for you to log in to LinkedIn. Handles 2FA and CAPTCHA naturally.
              </p>
              <button
                phx-click="linkedin_playwright_auth"
                class="glass-btn"
                style="width: 100%; padding: 10px; font-size: 0.85rem;"
                disabled={@linkedin_loading}
              >
                <%= if @linkedin_loading, do: "Authenticating...", else: "Launch Browser Login" %>
              </button>
            </div>

            <%!-- Method 2: Manual cookie paste --%>
            <div style="padding: 16px; border-radius: 10px; background: rgba(255,255,255,0.03); border: 1px solid rgba(255,255,255,0.06);">
              <div style="font-weight: 600; font-size: 0.9rem; margin-bottom: 6px;">🍪 Manual Cookie Paste</div>
              <p class="text-muted" style="font-size: 0.78rem; margin: 0 0 12px 0;">
                Paste your <code style="color: #c4b5fd;">li_at</code> cookie value from browser DevTools → Application → Cookies.
              </p>
              <form phx-submit="linkedin_manual_auth" style="display: flex; flex-direction: column; gap: 8px;">
                <textarea
                  name="cookies"
                  value={@manual_cookies}
                  phx-keyup="update_manual_cookies"
                  placeholder="li_at=AQE... or full Cookie header"
                  rows="2"
                  class="glass-input"
                  style="font-size: 0.8rem; resize: vertical; padding: 8px 12px;"
                ></textarea>
                <button type="submit" class="glass-btn" style="padding: 10px; font-size: 0.85rem;" disabled={@linkedin_loading}>
                  Save Cookies
                </button>
              </form>
            </div>
          </div>

          <%!-- Validate button --%>
          <%= if @linkedin_auth && @linkedin_auth["valid"] do %>
            <div style="margin-top: 16px; display: flex; gap: 12px;">
              <button phx-click="linkedin_validate" class="glass-btn" style="padding: 8px 20px; font-size: 0.85rem; background: rgba(74, 222, 128, 0.15); border-color: rgba(74, 222, 128, 0.3); color: #86efac;" disabled={@linkedin_loading}>
                Re-validate Cookies
              </button>
              <span class="text-muted" style="font-size: 0.78rem; align-self: center;">
                Test that saved cookies still work against LinkedIn's API
              </span>
            </div>
          <% end %>
        </div>
        <% end %>

        <form phx-submit="search" style="margin-bottom: 32px;">
          <div style="display: flex; gap: 10px;">
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Search expertise... e.g. 'how to use claude code hooks'"
              class="glass-input"
              autocomplete="off"
              autofocus
            />
            <button type="submit" class="glass-btn" disabled={@searching} style="white-space: nowrap;">
              {if @searching, do: "Searching...", else: "Search"}
            </button>
          </div>
        </form>

        <div :if={@error} class="glass-error" style="margin-bottom: 24px;">
          <strong>Error:</strong> {@error}
        </div>

        <div :if={@searching} style="display: flex; justify-content: center; padding: 48px 0;">
          <div class="glass-spinner"></div>
        </div>

        <div :if={!@searching && @results != []}>
          <p class="text-muted" style="font-size: 0.85rem; margin-bottom: 16px;">
            Found <span class="text-accent">{length(@results)}</span> results
            for "<span style="color: #e2e8f0;">{@query}</span>"
          </p>

          <div style="display: flex; flex-direction: column; gap: 16px;">
            <div :for={result <- @results} class="glass-card" style="padding: 20px;">
              <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px;">
                <div>
                  <span style="font-weight: 600; color: #e2e8f0;">
                    {result["author"]}
                  </span>
                  <span class="text-muted" style="font-size: 0.8rem; margin-left: 8px;">
                    {result["time_relative"]}
                  </span>
                </div>
                <span class="score-badge">
                  {result["score"] |> Float.round(3)}
                </span>
              </div>
              <div style="display: flex; gap: 12px; font-size: 0.75rem; margin-bottom: 8px;" class="text-muted">
                <span>{result["likes"]} likes</span>
                <span>{result["comments"]} comments</span>
                <span>{result["reposts"]} reposts</span>
              </div>
              <p style="color: rgba(226, 232, 240, 0.8); line-height: 1.6; margin: 0; font-size: 0.92rem;">
                {result["text"] |> String.slice(0, 400)}{if String.length(result["text"] || "") > 400, do: "...", else: ""}
              </p>
            </div>
          </div>
        </div>

        <div :if={!@searching && @results == [] && @query == ""} style="text-align: center; padding: 48px 0;">
          <p class="text-muted" style="font-size: 1.1rem;">Enter a query to search the expertise vault</p>
          <p class="text-muted" style="font-size: 0.85rem; margin-top: 4px;">
            Powered by FAISS semantic search with query expansion
          </p>
        </div>

        <div :if={!@searching && @results == [] && @query != "" && !@error} style="text-align: center; padding: 48px 0;">
          <p class="text-muted" style="font-size: 1.1rem;">No results found for "{@query}"</p>
        </div>
      </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
    <script>mermaid.initialize({startOnLoad: true, theme: 'dark'});</script>
    """
  end
end

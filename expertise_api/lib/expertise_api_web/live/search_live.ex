defmodule ExpertiseApiWeb.SearchLive do
  use ExpertiseApiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:query, "")
     |> assign(:results, [])
     |> assign(:searching, false)
     |> assign(:error, nil)
     |> assign(:page_title, "Claude Expertise Search")}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) when byte_size(query) > 1 do
    send(self(), {:do_search, query})
    {:noreply, assign(socket, query: query, searching: true, error: nil)}
  end

  def handle_event("search", _params, socket) do
    {:noreply, assign(socket, results: [], error: nil, searching: false)}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-300 text-base-content">
      <div class="max-w-3xl mx-auto px-4 py-8">
        <header class="mb-8 text-center">
          <h1 class="text-3xl font-bold text-purple-500">Claude Expertise</h1>
          <p class="text-base-content/60 mt-2">Search expert knowledge from Claude Code practitioners</p>
        </header>

        <form phx-submit="search" class="mb-8">
          <div class="relative">
            <svg
              class="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-base-content/40"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              />
            </svg>
            <input
              type="text"
              name="query"
              value={@query}
              placeholder="Search tips, patterns, workflows..."
              class="w-full bg-base-200 border border-base-content/20 rounded-lg px-4 py-3 pl-10 text-base-content placeholder:text-base-content/40 focus:outline-none focus:border-purple-500 focus:ring-1 focus:ring-purple-500"
              autofocus
            />
          </div>
        </form>

        <div :if={@searching} class="text-center py-8">
          <div class="animate-spin h-8 w-8 border-2 border-purple-500 border-t-transparent rounded-full mx-auto">
          </div>
          <p class="text-base-content/60 mt-4">Searching...</p>
        </div>

        <div :if={@error} class="text-center py-8">
          <p class="text-error">{@error}</p>
        </div>

        <div :if={!@searching && @results != []} class="space-y-4">
          <p class="text-sm text-base-content/60 mb-4">
            {@query |> then(&"Found #{length(@results)} results for \"#{&1}\"")}
          </p>
          <div :for={result <- @results} class="bg-base-200 rounded-lg p-4 border border-base-content/10">
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center gap-3">
                <div class="w-16 bg-base-300 rounded-full h-2">
                  <div
                    class="bg-purple-500 h-2 rounded-full"
                    style={"width: #{round(result["score"] * 100)}%"}
                  >
                  </div>
                </div>
                <span class="text-sm font-mono text-purple-400">
                  {result["score"] |> Float.round(3)}
                </span>
              </div>
              <div class="flex items-center gap-3 text-xs text-base-content/50">
                <span>{result["author"]}</span>
                <span>{result["time_relative"]}</span>
              </div>
            </div>
            <div class="flex gap-3 text-xs text-base-content/40 mb-2">
              <span>👍 {result["likes"]}</span>
              <span>💬 {result["comments"]}</span>
              <span>🔄 {result["reposts"]}</span>
            </div>
            <p class="text-sm leading-relaxed">
              {result["text"] |> String.slice(0, 400)}{if String.length(result["text"] || "") > 400, do: "...", else: ""}
            </p>
          </div>
        </div>

        <div
          :if={!@searching && @results == [] && @query == ""}
          class="text-center py-16"
        >
          <p class="text-5xl mb-4">✨</p>
          <p class="text-base-content/60">Search Claude Code tips & patterns from expert practitioners</p>
        </div>

        <div
          :if={!@searching && @results == [] && @query != "" && !@error}
          class="text-center py-16"
        >
          <p class="text-base-content/60">No results found for "{@query}"</p>
        </div>
      </div>
    </div>
    """
  end
end

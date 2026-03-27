defmodule ExpertiseApi.AuthoritySyncer do
  @moduledoc """
  GenServer that periodically fetches new content from tracked authority sources.

  - Checks for due authorities every 5 minutes.
  - Dispatches per-authority sync via fetch.py (respects each authority's interval_hours).
  - Browser-only authorities (LinkedIn) are skipped — the userscript handles those.
  - Manual sync can be triggered via `AuthoritySyncer.sync_now/1`.
  """

  use GenServer
  require Logger

  # Check every 5 minutes whether any authority is due
  @check_interval_ms 5 * 60 * 1_000

  # ── Public API ──────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Manually trigger an immediate sync for a specific authority slug."
  def sync_now(slug) when is_binary(slug) do
    GenServer.cast(__MODULE__, {:sync, slug})
  end

  @doc "Return the current syncer state (last_checked, active_sync)."
  def status do
    GenServer.call(__MODULE__, :status)
  end

  # ── GenServer callbacks ─────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    Logger.info("AuthoritySyncer: starting, check interval #{@check_interval_ms}ms")
    schedule_check()
    {:ok, %{last_checked: nil, active_syncs: MapSet.new()}}
  end

  @impl true
  def handle_info(:check_due, state) do
    state = do_check_due(state)
    schedule_check()
    {:noreply, %{state | last_checked: DateTime.utc_now()}}
  end

  @impl true
  def handle_cast({:sync, slug}, state) do
    if MapSet.member?(state.active_syncs, slug) do
      Logger.debug("AuthoritySyncer: #{slug} already syncing, skipping")
      {:noreply, state}
    else
      Task.start(fn -> do_sync(slug) end)
      {:noreply, %{state | active_syncs: MapSet.put(state.active_syncs, slug)}}
    end
  end

  @impl true
  def handle_cast({:sync_done, slug}, state) do
    {:noreply, %{state | active_syncs: MapSet.delete(state.active_syncs, slug)}}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply,
     %{
       last_checked: state.last_checked,
       active_syncs: MapSet.to_list(state.active_syncs)
     }, state}
  end

  # ── Internals ───────────────────────────────────────────────────────────────

  defp schedule_check do
    Process.send_after(self(), :check_due, @check_interval_ms)
  end

  defp do_check_due(state) do
    case ExpertiseApi.Authorities.list_due() do
      {:ok, %{"due" => due_list}} when is_list(due_list) and length(due_list) > 0 ->
        Logger.info("AuthoritySyncer: #{length(due_list)} authority/authorities due for sync")

        Enum.each(due_list, fn slug ->
          unless MapSet.member?(state.active_syncs, slug) do
            Task.start(fn -> do_sync(slug) end)
          end
        end)

        %{state | active_syncs: MapSet.union(state.active_syncs, MapSet.new(due_list))}

      {:ok, _} ->
        state

      {:error, reason} ->
        Logger.warning("AuthoritySyncer: list_due failed: #{reason}")
        state
    end
  end

  defp do_sync(slug) do
    Logger.info("AuthoritySyncer: syncing '#{slug}'")

    result =
      case ExpertiseApi.Authorities.sync(slug) do
        {:ok, %{"status" => "ok", "new_posts" => n}} ->
          Logger.info("AuthoritySyncer: '#{slug}' synced — #{n} new post(s)")
          {:ok, n}

        {:ok, %{"status" => "browser-only"}} ->
          Logger.debug("AuthoritySyncer: '#{slug}' is browser-only, skipping")
          {:ok, 0}

        {:ok, %{"status" => "paused"}} ->
          Logger.debug("AuthoritySyncer: '#{slug}' is paused, skipping")
          {:ok, 0}

        {:ok, %{"status" => "error", "error" => err}} ->
          Logger.warning("AuthoritySyncer: '#{slug}' sync error: #{err}")
          {:error, err}

        {:error, reason} ->
          Logger.warning("AuthoritySyncer: '#{slug}' fetch failed: #{reason}")
          {:error, reason}

        other ->
          Logger.debug("AuthoritySyncer: '#{slug}' returned: #{inspect(other)}")
          {:ok, 0}
      end

    # Broadcast sync completion via PubSub so LiveView can update
    case result do
      {:ok, new_posts} ->
        Phoenix.PubSub.broadcast(
          ExpertiseApi.PubSub,
          "authority:sync",
          {:sync_complete, slug, new_posts}
        )

      _ ->
        :ok
    end

    GenServer.cast(__MODULE__, {:sync_done, slug})
  end
end

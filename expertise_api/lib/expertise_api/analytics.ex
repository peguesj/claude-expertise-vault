defmodule ExpertiseApi.Analytics do
  @moduledoc """
  Bridge module for analytics — delegates to Python database.py analytics commands.
  """

  defp run_cmd(args) do
    case System.cmd("python3", ["scripts/database.py" | args],
           cd: Path.join(File.cwd!(), ".."),
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:ok, %{"raw" => String.trim(output)}}
        end

      {output, _code} ->
        {:error, "analytics command failed: #{String.trim(output)}"}
    end
  end

  def log_search(query, mode, result_count, latency_ms) do
    run_cmd([
      "analytics-log",
      "--query", to_string(query),
      "--mode", to_string(mode),
      "--result-count", to_string(result_count),
      "--latency-ms", to_string(latency_ms)
    ])
  end

  def log_interaction(query, post_id, action, dwell_ms) do
    run_cmd([
      "analytics-interaction",
      "--query", to_string(query),
      "--post-id", to_string(post_id),
      "--action", to_string(action),
      "--dwell-ms", to_string(dwell_ms)
    ])
  end

  def top_queries(limit \\ 20) do
    run_cmd(["analytics-top", "--limit", to_string(limit)])
  end

  def recommendations do
    run_cmd(["analytics-recommendations"])
  end

  def preferences do
    run_cmd(["analytics-preferences"])
  end

  def insights_feed(limit \\ 20) do
    run_cmd(["insights-feed", "--limit", to_string(limit)])
  end
end

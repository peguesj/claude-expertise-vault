defmodule ExpertiseApiWeb.AnalyticsController do
  use ExpertiseApiWeb, :controller

  def log_search(conn, %{"query" => query} = params) do
    mode = Map.get(params, "mode", "search")
    result_count = Map.get(params, "result_count", 0)
    latency_ms = Map.get(params, "latency_ms", 0)

    case ExpertiseApi.Analytics.log_search(query, mode, result_count, latency_ms) do
      {:ok, result} -> json(conn, result)
      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: to_string(reason)})
    end
  end

  def log_search(conn, _params) do
    conn |> put_status(422) |> json(%{error: "Missing required parameter: query"})
  end

  def log_interaction(conn, %{"query" => query, "post_id" => post_id} = params) do
    action = Map.get(params, "action", "click")
    dwell_ms = Map.get(params, "dwell_ms", 0)

    case ExpertiseApi.Analytics.log_interaction(query, post_id, action, dwell_ms) do
      {:ok, result} -> json(conn, result)
      {:error, reason} ->
        conn |> put_status(422) |> json(%{error: to_string(reason)})
    end
  end

  def log_interaction(conn, _params) do
    conn |> put_status(422) |> json(%{error: "Missing required parameters: query, post_id"})
  end

  def top_queries(conn, params) do
    limit = params |> Map.get("limit", "20") |> to_string() |> String.to_integer()

    case ExpertiseApi.Analytics.top_queries(limit) do
      {:ok, result} -> json(conn, result)
      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: to_string(reason)})
    end
  end

  def recommendations(conn, _params) do
    case ExpertiseApi.Analytics.recommendations() do
      {:ok, result} -> json(conn, result)
      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: to_string(reason)})
    end
  end

  def preferences(conn, _params) do
    case ExpertiseApi.Analytics.preferences() do
      {:ok, result} -> json(conn, result)
      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: to_string(reason)})
    end
  end
end

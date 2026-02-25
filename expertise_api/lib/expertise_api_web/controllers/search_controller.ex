defmodule ExpertiseApiWeb.SearchController do
  use ExpertiseApiWeb, :controller

  def search(conn, %{"q" => ""}) do
    json(conn, %{query: "", results: [], count: 0})
  end

  def search(conn, %{"q" => query} = params) do
    top_k = params |> Map.get("top_k", "5") |> String.to_integer()
    min_score = params |> Map.get("min_score", "0.25") |> String.to_float()

    case ExpertiseApi.Search.search(query, top_k: top_k, min_score: min_score) do
      {:ok, results} ->
        json(conn, %{query: query, results: results, count: length(results)})

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: to_string(reason)})
    end
  end

  def search(conn, _params) do
    json(conn, %{query: "", results: [], count: 0})
  end

  def health(conn, _params) do
    json(conn, %{status: "ok", service: "expertise_api"})
  end
end

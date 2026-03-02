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

  def scan(conn, params) do
    author = Map.get(params, "author", "mitko-vasilev")

    case ExpertiseApi.Pipeline.scan(author) do
      {:ok, result} ->
        json(conn, %{status: "ok", action: "scan", result: result})

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: to_string(reason)})
    end
  end

  def import_data(conn, params) do
    author = Map.get(params, "author", "mitko-vasilev")

    case ExpertiseApi.Pipeline.run_pipeline(author) do
      {:ok, result} ->
        json(conn, %{status: "ok", action: "import", result: result})

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: to_string(reason)})
    end
  end

  def scrape_images(conn, params) do
    author = Map.get(params, "author", "mitko-vasilev")

    case ExpertiseApi.Pipeline.scrape_images(author) do
      {:ok, result} ->
        json(conn, %{status: "ok", action: "scrape_images", result: result})

      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: to_string(reason)})
    end
  end

  def stats(conn, _params) do
    case ExpertiseApi.Pipeline.stats() do
      {:ok, result} -> json(conn, result)
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: to_string(reason)})
    end
  end

  def ingest(conn, %{"posts" => posts}) when is_list(posts) do
    case ExpertiseApi.Ingest.ingest_posts(posts) do
      {:ok, result} ->
        json(conn, %{status: "ok", action: "ingest", ingested: result})

      {:error, reason} ->
        conn
        |> put_status(422)
        |> json(%{error: to_string(reason)})
    end
  end

  def ingest(conn, post) when is_map(post) do
    ingest(conn, %{"posts" => [post]})
  end

  def ask(conn, %{"q" => question} = params) do
    top_k = params |> Map.get("top_k", "8") |> to_string() |> String.to_integer()
    no_ai = params |> Map.get("no_ai", "false") |> to_string()

    case ExpertiseApi.Ask.ask(question, top_k: top_k, no_ai: no_ai == "true") do
      {:ok, result} -> json(conn, result)
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: to_string(reason)})
    end
  end

  def ask(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing required parameter: q"})
  end

  def taxonomy(conn, _params) do
    case ExpertiseApi.Database.taxonomy() do
      {:ok, result} -> json(conn, result)
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: to_string(reason)})
    end
  end

  def resources(conn, params) do
    type = Map.get(params, "type")
    tag = Map.get(params, "tag")

    case ExpertiseApi.Database.resources(type: type, tag: tag) do
      {:ok, result} -> json(conn, %{resources: result, count: length(result)})
      {:error, reason} ->
        conn
        |> put_status(500)
        |> json(%{error: to_string(reason)})
    end
  end
end

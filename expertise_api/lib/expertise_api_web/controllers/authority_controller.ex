defmodule ExpertiseApiWeb.AuthorityController do
  use ExpertiseApiWeb, :controller

  alias ExpertiseApi.Authorities
  alias ExpertiseApi.AuthoritySyncer

  # GET /api/authorities
  def index(conn, params) do
    status = Map.get(params, "status")

    case Authorities.list(status) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> conn |> put_status(500) |> json(%{error: reason})
    end
  end

  # GET /api/authorities/:slug
  def show(conn, %{"slug" => slug}) do
    case Authorities.get(slug) do
      {:ok, authority} -> json(conn, authority)
      {:error, "not found"} -> conn |> put_status(404) |> json(%{error: "Authority not found"})
      {:error, reason} -> conn |> put_status(500) |> json(%{error: reason})
    end
  end

  # POST /api/authorities
  def create(conn, params) do
    slug = params["slug"]
    name = params["name"]
    platform = params["platform"]
    profile_url = params["profile_url"]

    if is_nil(slug) or is_nil(name) or is_nil(platform) or is_nil(profile_url) do
      conn |> put_status(422) |> json(%{error: "slug, name, platform, profile_url are required"})
    else
      opts = [
        fetch_url: params["fetch_url"],
        status: params["status"],
        adapter: params["adapter"],
        interval: params["interval_hours"] && String.to_integer("#{params["interval_hours"]}"),
        tags: params["tags"] && Enum.join(List.wrap(params["tags"]), ","),
      ]

      case Authorities.add(slug, name, platform, profile_url, opts) do
        {:ok, data} -> conn |> put_status(201) |> json(data)
        {:error, reason} -> conn |> put_status(500) |> json(%{error: reason})
      end
    end
  end

  # POST /api/authorities/:slug/sync
  def sync(conn, %{"slug" => slug}) do
    AuthoritySyncer.sync_now(slug)
    json(conn, %{status: "sync_queued", slug: slug})
  end

  # GET /api/authorities/due
  def due(conn, _params) do
    case Authorities.list_due() do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> conn |> put_status(500) |> json(%{error: reason})
    end
  end

  # POST /api/authorities/recalculate-credibility
  def recalculate_credibility(conn, _params) do
    case Authorities.recalculate_credibility() do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> conn |> put_status(500) |> json(%{error: reason})
    end
  end

  # GET /api/authorities/syncer/status
  def syncer_status(conn, _params) do
    status = AuthoritySyncer.status()

    json(conn, %{
      last_checked: status.last_checked && DateTime.to_iso8601(status.last_checked),
      active_syncs: status.active_syncs
    })
  end
end

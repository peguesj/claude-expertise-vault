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
    profile_url = params["profile_url"]

    # Auto-detect platform from LinkedIn URLs
    platform = params["platform"] || detect_platform(profile_url)

    if is_nil(slug) or is_nil(name) or is_nil(platform) or is_nil(profile_url) do
      conn |> put_status(422) |> json(%{error: "slug, name, platform, profile_url are required"})
    else
      fetch_url = params["fetch_url"]
      is_linkedin = platform == "linkedin" or linkedin_url?(profile_url)

      # Auto-configure LinkedIn authorities with rss.app feed URLs
      {adapter, status} = cond do
        is_linkedin and rss_app_url?(fetch_url) ->
          {"linkedin-rss", params["status"] || "active"}

        is_linkedin and is_nil(fetch_url) ->
          {nil, params["status"] || "browser-only"}

        true ->
          {params["adapter"], params["status"]}
      end

      opts = [
        fetch_url: fetch_url,
        status: status,
        adapter: adapter,
        interval: params["interval_hours"] && String.to_integer("#{params["interval_hours"]}"),
        tags: params["tags"] && Enum.join(List.wrap(params["tags"]), ","),
      ]

      case Authorities.add(slug, name, platform, profile_url, opts) do
        {:ok, data} ->
          response = if is_linkedin and not rss_app_url?(fetch_url) do
            Map.merge(data, %{
              "hint" => "To enable automatic sync, generate an RSS feed at https://rss.app/rss-feed/linkedin and update this authority with the feed URL as fetch_url.",
              "rss_setup_url" => "https://rss.app/rss-feed/linkedin"
            })
          else
            data
          end

          conn |> put_status(201) |> json(response)

        {:error, reason} ->
          conn |> put_status(500) |> json(%{error: reason})
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

  # POST /api/authorities/linkedin/auth
  def linkedin_auth(conn, params) do
    method = params["method"] || "playwright"
    cookies = params["cookies"]

    result =
      if method == "manual" and is_binary(cookies) do
        ExpertiseApi.LinkedInAuth.authenticate_manual(cookies)
      else
        ExpertiseApi.LinkedInAuth.authenticate(method)
      end

    case result do
      {:ok, %{"status" => "authenticated"} = data} ->
        json(conn, data)

      {:ok, %{"status" => "error"} = data} ->
        conn |> put_status(422) |> json(data)

      {:ok, data} ->
        json(conn, data)

      {:error, reason} ->
        conn |> put_status(500) |> json(%{error: reason})
    end
  end

  # GET /api/authorities/linkedin/auth-status
  def linkedin_auth_status(conn, _params) do
    case ExpertiseApi.LinkedInAuth.status() do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> conn |> put_status(500) |> json(%{error: reason})
    end
  end

  # ── Private helpers ──────────────────────────────────────────────────────────

  defp linkedin_url?(nil), do: false
  defp linkedin_url?(url), do: String.contains?(url, "linkedin.com/")

  defp rss_app_url?(nil), do: false
  defp rss_app_url?(url), do: String.contains?(url, "rss.app/feed")

  defp detect_platform(nil), do: nil
  defp detect_platform(url) do
    cond do
      linkedin_url?(url) -> "linkedin"
      String.contains?(url, "github.com/") -> "github"
      true -> nil
    end
  end
end

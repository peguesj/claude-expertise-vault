defmodule ExpertiseApi.Authorities do
  @moduledoc """
  Bridge module for authority source management — delegates to Python database.py and fetch.py.
  """

  defp run_db(args) do
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
        {:error, "authority command failed: #{String.trim(output)}"}
    end
  end

  defp run_fetch(args) do
    case System.cmd("python3", ["scripts/fetch.py" | args],
           cd: Path.join(File.cwd!(), ".."),
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:ok, %{"raw" => String.trim(output)}}
        end

      {output, _code} ->
        {:error, "fetch command failed: #{String.trim(output)}"}
    end
  end

  def list(status \\ nil) do
    args = if status, do: ["authority-list", "--status", status], else: ["authority-list"]
    run_db(args)
  end

  def get(slug) do
    # Pull from list and filter — single-row lookup via list
    case list() do
      {:ok, %{"authorities" => auths}} ->
        case Enum.find(auths, fn a -> a["slug"] == slug end) do
          nil -> {:error, "not found"}
          auth -> {:ok, auth}
        end

      err ->
        err
    end
  end

  def add(slug, name, platform, profile_url, opts \\ []) do
    args = [
      "authority-add",
      "--slug", slug,
      "--name", name,
      "--platform", platform,
      "--profile-url", profile_url
    ]

    args =
      args
      |> maybe_append("--fetch-url", opts[:fetch_url])
      |> maybe_append("--status", opts[:status])
      |> maybe_append("--adapter", opts[:adapter])
      |> maybe_append("--interval", opts[:interval] && to_string(opts[:interval]))
      |> maybe_append("--tags", opts[:tags])

    run_db(args)
  end

  def list_due do
    run_db(["authority-due"])
  end

  def sync_done(slug, new_posts \\ 0, error \\ nil) do
    args = ["authority-sync-done", "--slug", slug, "--new-posts", to_string(new_posts)]
    args = if error, do: args ++ ["--error", to_string(error)], else: args
    run_db(args)
  end

  def recalculate_credibility do
    run_db(["authority-credibility"])
  end

  def sync(slug) do
    run_fetch(["--slug", slug])
  end

  def sync_all_due do
    run_fetch(["--sync-all-due"])
  end

  defp maybe_append(args, _flag, nil), do: args
  defp maybe_append(args, _flag, ""), do: args
  defp maybe_append(args, flag, value), do: args ++ [flag, value]
end

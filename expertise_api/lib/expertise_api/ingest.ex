defmodule ExpertiseApi.Ingest do
  @moduledoc """
  Handles ingestion of posts from the userscript and other sources.
  Appends to raw JSONL and triggers re-indexing.
  """

  def ingest_posts(posts) when is_list(posts) do
    root = project_root()

    results =
      posts
      |> Enum.map(&normalize_post/1)
      |> Enum.map(fn post ->
        author_slug = post["author"]
          |> to_string()
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9]+/, "-")
          |> String.trim("-")

        author_slug = if author_slug == "", do: "unknown", else: author_slug
        raw_path = Path.join([root, "data", "raw", "#{author_slug}.jsonl"])

        # Ensure directory exists
        File.mkdir_p!(Path.dirname(raw_path))

        # Append post as JSONL
        line = Jason.encode!(post) <> "\n"
        File.write!(raw_path, line, [:append])

        %{id: post["id"], author: author_slug, status: "ingested"}
      end)

    # Also insert into SQLite via Python
    db_script = Path.join(root, "scripts/database.py")
    if File.exists?(db_script) do
      for post <- posts do
        author_slug = post["author"]
          |> to_string()
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9]+/, "-")
          |> String.trim("-")
        author_slug = if author_slug == "", do: "unknown", else: author_slug

        System.cmd("python3", [db_script, "import", "--author", author_slug],
          cd: root, stderr_to_stdout: true)
      end
    end

    {:ok, results}
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp normalize_post(post) do
    # Ensure required fields exist
    id = post["id"] || generate_id(post)

    %{
      "id" => id,
      "author" => post["author"] || "unknown",
      "platform" => post["platform"] || "other",
      "url" => post["url"] || "",
      "text" => post["text"] || "",
      "time_relative" => post["time_relative"] || "",
      "scraped_date" => post["scraped_date"] || DateTime.utc_now() |> DateTime.to_iso8601(),
      "likes" => post["likes"] || 0,
      "comments" => post["comments"] || 0,
      "reposts" => post["reposts"] || 0,
      "media" => post["media"] || [],
      "links" => post["links"] || [],
      "tags" => post["tags"] || []
    }
  end

  defp generate_id(post) do
    platform = post["platform"] || "other"
    hash = :crypto.hash(:sha256, (post["text"] || "") <> (post["url"] || ""))
      |> Base.encode16(case: :lower)
      |> String.slice(0, 8)
    "#{platform}-#{hash}"
  end

  defp project_root do
    Application.get_env(:expertise_api, :project_root, Path.expand("../../..", __DIR__))
  end
end

defmodule ExpertiseApi.Pipeline do
  @moduledoc "Orchestrates the Python data pipeline: ingest, embed, scrape images."

  def scan(author) do
    run_script("scrape_images.py", ["--author", author, "--update-raw"])
  end

  def run_pipeline(author) do
    with {:ok, ingest_result} <- run_script("ingest.py", ["--author", author]),
         {:ok, embed_result} <- run_script("embed.py", []) do
      {:ok, %{
        "ingest" => ingest_result,
        "embed" => embed_result
      }}
    end
  end

  def scrape_images(author) do
    run_script("scrape_images.py", ["--author", author])
  end

  def stats do
    root = project_root()
    raw_dir = Path.join(root, "data/raw")
    processed_dir = Path.join(root, "data/processed")
    images_dir = Path.join(root, "data/images")
    index_path = Path.join(root, "vectorstore/index.bin")

    raw_count = count_jsonl_lines(raw_dir)
    processed_count = count_jsonl_lines(processed_dir)
    image_count = count_images(images_dir)
    index_exists = File.exists?(index_path)

    {:ok, %{
      raw_posts: raw_count,
      processed_chunks: processed_count,
      images: image_count,
      index_exists: index_exists,
      authors: list_authors(raw_dir)
    }}
  end

  defp run_script(script, args) do
    script_path = Path.join(project_root(), "scripts/#{script}")

    case System.cmd("python3", [script_path | args],
           stderr_to_stdout: true,
           cd: project_root()
         ) do
      {output, 0} -> {:ok, output}
      {output, code} -> {:error, "Script #{script} exited with #{code}: #{output}"}
    end
  end

  defp count_jsonl_lines(dir) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".jsonl"))
      |> Enum.reduce(0, fn file, acc ->
        path = Path.join(dir, file)
        lines = path |> File.read!() |> String.split("\n") |> Enum.count(&(&1 != ""))
        acc + lines
      end)
    else
      0
    end
  end

  defp count_images(dir) do
    if File.dir?(dir) do
      case System.cmd("find", [dir, "-type", "f", "-name", "*.jpg", "-o",
                                "-name", "*.jpeg", "-o", "-name", "*.png", "-o",
                                "-name", "*.gif", "-o", "-name", "*.webp"],
                       stderr_to_stdout: true) do
        {output, 0} ->
          output |> String.split("\n") |> Enum.count(&(&1 != ""))
        _ -> 0
      end
    else
      0
    end
  end

  defp list_authors(dir) do
    if File.dir?(dir) do
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".jsonl"))
      |> Enum.map(&String.replace(&1, ".jsonl", ""))
    else
      []
    end
  end

  defp project_root do
    Application.get_env(:expertise_api, :project_root, Path.expand("../../..", __DIR__))
  end
end

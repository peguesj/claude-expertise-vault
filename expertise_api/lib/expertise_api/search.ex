defmodule ExpertiseApi.Search do
  @moduledoc "Bridge to Python FAISS vector search"

  def search(query, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 5)
    min_score = Keyword.get(opts, :min_score, 0.2)

    args = [
      search_script_path(),
      query,
      "--top-k", to_string(top_k),
      "--min-score", to_string(min_score),
      "--json"
    ]

    case System.cmd("python3", args, stderr_to_stdout: true, cd: project_root()) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, results} -> {:ok, results}
          {:error, _} -> {:error, :invalid_json}
        end

      {error_output, _code} ->
        {:error, error_output}
    end
  end

  defp search_script_path do
    Path.join(project_root(), "scripts/search.py")
  end

  defp project_root do
    Application.get_env(:expertise_api, :project_root, Path.expand("../../..", __DIR__))
  end
end

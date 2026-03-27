defmodule ExpertiseApi.Ask do
  @moduledoc "Bridge to Python AI Q&A and content-parsing system."

  @doc "Answer a question grounded in the expertise knowledge base."
  def ask(question, opts \\ []) do
    top_k = Keyword.get(opts, :top_k, 8)
    no_ai  = Keyword.get(opts, :no_ai, false)

    args =
      [ask_script_path(), question, "--top-k", to_string(top_k), "--json"]
      |> then(fn a -> if no_ai, do: a ++ ["--no-ai"], else: a end)

    case System.cmd("python3", args,
           stderr_to_stdout: true,
           cd: project_root(),
           env: proxy_env()
         ) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, result} -> {:ok, result}
          {:error, _}   -> {:error, :invalid_json}
        end

      {error_output, _code} ->
        {:error, error_output}
    end
  end

  @doc """
  Parse raw post content with Claude to extract structured insights.
  Calls scripts/claude_parse.py, which tries the local proxy first then claude CLI.
  Returns a map with answer, key_insights, topics, tags, and resources fields.
  """
  def parse_with_claude(content, prompt \\ "", url \\ "") do
    script = Path.join(project_root(), "scripts/claude_parse.py")
    python = System.find_executable("python3") || "python3"

    base_args = [script, "--content", String.slice(content, 0, 8000)]
    args_with_prompt = if prompt != "", do: base_args ++ ["--prompt", prompt], else: base_args
    final_args = if url != "", do: args_with_prompt ++ ["--url", url], else: args_with_prompt

    case System.cmd(python, final_args,
           stderr_to_stdout: true,
           cd: project_root(),
           env: proxy_env(),
           timeout: 90_000
         ) do
      {output, 0} ->
        case Jason.decode(String.trim(output)) do
          {:ok, result} -> result
          {:error, _}   ->
            %{"answer" => output, "key_insights" => [], "topics" => [],
              "tags" => [], "resources" => []}
        end

      {error, _code} ->
        %{"error" => "Parse failed", "details" => error}
    end
  end

  @doc "Persist a parsed result's answer to the SQLite insights table."
  def save_parse_result(post_id, _author, result) do
    if Map.has_key?(result, "answer") do
      script = Path.join(project_root(), "scripts/database.py")
      python = System.find_executable("python3") || "python3"
      answer = Map.get(result, "answer", "")
      tags   = result |> Map.get("tags", []) |> Enum.join(",")

      System.cmd(python,
        [script, "add-insight", "--post-id", post_id, "--insight", answer, "--tags", tags],
        stderr_to_stdout: true,
        cd: project_root()
      )
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp proxy_env do
    [
      {"LITELLM_PROXY_URL", System.get_env("LITELLM_PROXY_URL", "http://localhost:8082")},
      {"AI_MODEL",          System.get_env("AI_MODEL",          "claude-sonnet-4-6")}
    ]
  end

  defp ask_script_path, do: Path.join(project_root(), "scripts/ask.py")

  defp project_root do
    Application.get_env(:expertise_api, :project_root, Path.expand("../../..", __DIR__))
  end
end

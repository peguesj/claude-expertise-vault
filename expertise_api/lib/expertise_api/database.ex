defmodule ExpertiseApi.Database do
  @moduledoc "Bridge to Python SQLite database (scripts/database.py)"

  def taxonomy do
    run_db_command(["taxonomy", "--json"])
  end

  def resources(opts \\ []) do
    type = Keyword.get(opts, :type)
    tag = Keyword.get(opts, :tag)

    args = ["search", "--json"]
    args = if type, do: args ++ ["--type", type], else: args
    args = if tag, do: args ++ ["--tag", tag], else: args

    run_db_command(args)
  end

  defp run_db_command(args) do
    script = Path.join(project_root(), "scripts/database.py")

    case System.cmd("python3", [script | args],
           stderr_to_stdout: true,
           cd: project_root()
         ) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, result} -> {:ok, result}
          {:error, _} -> {:ok, output}
        end

      {error_output, _code} ->
        {:error, error_output}
    end
  end

  defp project_root do
    Application.get_env(:expertise_api, :project_root, Path.expand("../../..", __DIR__))
  end
end

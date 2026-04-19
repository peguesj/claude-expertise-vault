defmodule ExpertiseApi.LinkedInAuth do
  @moduledoc """
  Bridge to Python linkedin_auth.py for LinkedIn cookie management.

  Supports:
    - Browser-based authentication (Playwright)
    - Manual cookie paste
    - Cookie validation and status checks
    - Authenticated profile scraping
  """

  defp project_root, do: Path.join(File.cwd!(), "..")

  defp run(args, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    task =
      Task.async(fn ->
        System.cmd("python3", ["scripts/linkedin_auth.py" | args],
          cd: project_root(),
          stderr_to_stdout: true
        )
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, {output, 0}} ->
        case Jason.decode(output) do
          {:ok, data} -> {:ok, data}
          {:error, _} -> {:ok, %{"raw" => String.trim(output)}}
        end

      {:ok, {output, _code}} ->
        {:error, "linkedin auth failed: #{String.trim(output)}"}

      nil ->
        {:error, "linkedin auth timed out"}
    end
  end

  @doc "Launch browser-based LinkedIn authentication (opens Playwright window)."
  def authenticate(method \\ "playwright") do
    # Playwright auth needs a long timeout (user interaction)
    run(["auth", "--method", method], timeout: 360_000)
  end

  @doc "Authenticate with manually provided cookie string."
  def authenticate_manual(cookie_string) do
    run(["auth", "--method", "manual", "--cookies", cookie_string])
  end

  @doc "Validate that saved cookies are still working."
  def validate do
    run(["validate"])
  end

  @doc "Get current authentication status without validation."
  def status do
    run(["status"])
  end

  @doc "Scrape posts from a LinkedIn profile using saved cookies."
  def scrape(username, max_posts \\ 20) do
    run(["scrape", "--username", username, "--max-posts", to_string(max_posts)], timeout: 60_000)
  end
end

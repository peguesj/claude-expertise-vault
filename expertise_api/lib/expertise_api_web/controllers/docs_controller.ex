defmodule ExpertiseApiWeb.DocsController do
  use ExpertiseApiWeb, :controller

  @scalar_html """
  <!DOCTYPE html>
  <html>
  <head>
    <title>Expertise API Reference</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
  </head>
  <body>
    <script id="api-reference" data-url="/api/openapi.yaml" data-configuration='{"theme":"kepler","darkMode":true}'></script>
    <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
  </body>
  </html>
  """

  def docs(conn, _params) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, @scalar_html)
  end

  def openapi_spec(conn, _params) do
    paths = [
      Path.join(:code.priv_dir(:expertise_api) |> to_string(), "static/openapi.yaml"),
      Path.join(File.cwd!(), "openapi.yaml"),
      Path.join(File.cwd!(), "../openapi.yaml")
    ]

    case Enum.find(paths, &File.exists?/1) do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "openapi.yaml not found"})

      path ->
        conn
        |> put_resp_content_type("text/yaml")
        |> put_resp_header("access-control-allow-origin", "*")
        |> send_file(200, path)
    end
  end
end

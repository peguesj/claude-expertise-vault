defmodule ExpertiseApiWeb.Router do
  use ExpertiseApiWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExpertiseApiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug ExpertiseApiWeb.Plugs.CORS
  end

  scope "/", ExpertiseApiWeb do
    pipe_through :browser

    live "/", SearchLive, :index
    get "/docs", DocsController, :docs
  end

  scope "/api", ExpertiseApiWeb do
    pipe_through :api

    # Core search & query
    get "/search", SearchController, :search
    get "/health", SearchController, :health
    get "/stats", SearchController, :stats
    get "/ask", SearchController, :ask
    get "/taxonomy", SearchController, :taxonomy
    get "/resources", SearchController, :resources
    post "/scan", SearchController, :scan
    post "/import", SearchController, :import_data
    post "/scrape-images", SearchController, :scrape_images
    post "/ingest", SearchController, :ingest
    post "/ask", SearchController, :ask

    # OpenAPI spec
    get "/openapi.yaml", DocsController, :openapi_spec

    # Analytics
    post "/analytics/search", AnalyticsController, :log_search
    post "/analytics/interaction", AnalyticsController, :log_interaction
    get "/analytics/top-queries", AnalyticsController, :top_queries
    get "/analytics/recommendations", AnalyticsController, :recommendations
    get "/analytics/preferences", AnalyticsController, :preferences
  end
end

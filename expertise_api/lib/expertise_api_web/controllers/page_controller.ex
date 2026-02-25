defmodule ExpertiseApiWeb.PageController do
  use ExpertiseApiWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

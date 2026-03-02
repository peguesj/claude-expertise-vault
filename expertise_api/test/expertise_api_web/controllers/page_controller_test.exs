defmodule ExpertiseApiWeb.PageControllerTest do
  use ExpertiseApiWeb.ConnCase

  test "GET / renders Claude Expertise LiveView", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Claude Expertise"
  end
end

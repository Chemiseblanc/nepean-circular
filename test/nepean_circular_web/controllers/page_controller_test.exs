defmodule NepeanCircularWeb.PageControllerTest do
  use NepeanCircularWeb.ConnCase

  test "GET / renders homepage", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Nepean Circular"
  end

  test "GET / renders subscribe form", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "subscribe-form"
  end

  describe "POST /subscribe" do
    test "valid email redirects with success flash", %{conn: conn} do
      conn = post(conn, ~p"/subscribe", %{subscriber: %{email: "new@example.com"}})
      assert redirected_to(conn) == ~p"/"

      conn = get(recycle(conn), ~p"/")
      assert html_response(conn, 200) =~ "subscribed"
    end

    test "blank email redirects with error flash", %{conn: conn} do
      conn = post(conn, ~p"/subscribe", %{subscriber: %{email: ""}})
      assert redirected_to(conn) == ~p"/"

      conn = get(recycle(conn), ~p"/")
      assert html_response(conn, 200) =~ "valid email"
    end
  end
end

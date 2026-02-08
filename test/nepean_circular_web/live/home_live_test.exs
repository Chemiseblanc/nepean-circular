defmodule NepeanCircularWeb.HomeLiveTest do
  use NepeanCircularWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "subscribe form" do
    test "renders subscribe form with email input", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#subscribe-form")
      assert has_element?(view, "input[type=email]")
    end

    test "submitting valid email shows success flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      result =
        view
        |> form("#subscribe-form", %{subscriber: %{email: "new@example.com"}})
        |> render_submit()

      assert result =~ "subscribed"
    end

    test "submitting blank email shows error flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      result =
        view
        |> form("#subscribe-form", %{subscriber: %{email: ""}})
        |> render_submit()

      assert result =~ "valid email"
    end
  end
end

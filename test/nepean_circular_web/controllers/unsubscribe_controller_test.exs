defmodule NepeanCircularWeb.UnsubscribeControllerTest do
  use NepeanCircularWeb.ConnCase

  alias NepeanCircular.Flyers

  setup do
    {:ok, subscriber} = Flyers.subscribe(%{email: "unsub-test@example.com"})
    %{subscriber: subscriber}
  end

  describe "POST /unsubscribe" do
    test "unsubscribes with valid token", %{subscriber: subscriber} do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post("/unsubscribe", %{"token" => subscriber.token})

      assert response(conn, 200)

      {:ok, [updated]} = Flyers.get_subscriber_by_token(subscriber.token)
      assert updated.unsubscribed_at != nil
    end

    test "returns 200 with invalid token (no info leak)" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post("/unsubscribe", %{"token" => "invalid-token"})

      assert response(conn, 200)
    end

    test "returns 200 with missing token" do
      conn =
        build_conn()
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post("/unsubscribe", %{})

      assert response(conn, 200)
    end
  end

  describe "GET /unsubscribe" do
    test "unsubscribes with valid token and shows HTML", %{subscriber: subscriber} do
      conn = get(build_conn(), "/unsubscribe?token=#{subscriber.token}")

      assert html_response(conn, 200) =~ "Unsubscribed"

      {:ok, [updated]} = Flyers.get_subscriber_by_token(subscriber.token)
      assert updated.unsubscribed_at != nil
    end

    test "returns 200 with invalid token", %{conn: conn} do
      conn = get(conn, "/unsubscribe?token=bad-token")

      assert html_response(conn, 200) =~ "Unsubscribed"
    end
  end
end

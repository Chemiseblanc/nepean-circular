defmodule NepeanCircularWeb.UnsubscribeController do
  use NepeanCircularWeb, :controller

  alias NepeanCircular.Flyers

  def unsubscribe(conn, %{"token" => token}) do
    case Flyers.get_subscriber_by_token(token) do
      {:ok, [subscriber]} ->
        Flyers.unsubscribe(subscriber)
        render_success(conn)

      _ ->
        render_success(conn)
    end
  end

  def unsubscribe(conn, _params) do
    render_success(conn)
  end

  defp render_success(%{method: "GET"} = conn) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, """
    <!DOCTYPE html>
    <html>
    <head><title>Unsubscribed</title></head>
    <body style="font-family: sans-serif; text-align: center; padding-top: 60px;">
      <h1>Unsubscribed</h1>
      <p>You have been unsubscribed from weekly flyer emails.</p>
    </body>
    </html>
    """)
  end

  defp render_success(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Unsubscribed")
  end
end

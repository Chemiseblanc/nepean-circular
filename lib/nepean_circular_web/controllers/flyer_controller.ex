defmodule NepeanCircularWeb.FlyerController do
  use NepeanCircularWeb, :controller

  alias NepeanCircular.Pdf

  def combined(conn, _params) do
    path = Pdf.combined_pdf_file()

    if File.exists?(path) do
      conn
      |> put_resp_content_type("application/pdf")
      |> put_resp_header("content-disposition", ~s(inline; filename="weekly-flyers.pdf"))
      |> send_file(200, path)
    else
      conn
      |> put_status(:not_found)
      |> text("Combined flyer not available yet.")
    end
  end
end

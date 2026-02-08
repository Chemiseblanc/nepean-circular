defmodule NepeanCircularWeb.PageController do
  use NepeanCircularWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end

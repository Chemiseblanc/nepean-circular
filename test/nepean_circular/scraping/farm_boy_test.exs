defmodule NepeanCircular.Scraping.FarmBoyTest do
  use NepeanCircular.DataCase

  alias NepeanCircular.Flyers
  alias NepeanCircular.Scraping.FarmBoy

  setup do
    {:ok, store} =
      Flyers.create_store(%{
        name: "Farm Boy Test",
        url: "https://www.farmboy.ca/weekly-flyer-specials/",
        scraper_module: NepeanCircular.Scraping.FarmBoy
      })

    %{store: store}
  end

  test "extracts PDF links from wp-content/uploads", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Req.Test.html(conn, """
      <html>
        <body>
          <a href="https://www.farmboy.ca/wp-content/uploads/2025/02/FMBOY_0201_GameDay-1.pdf">
            Weekly Flyer
          </a>
          <a href="https://www.farmboy.ca/about">About</a>
        </body>
      </html>
      """)
    end)

    {:ok, flyers} = FarmBoy.scrape(store)

    assert length(flyers) == 1

    flyer = hd(flyers)

    assert flyer.pdf_url ==
             "https://www.farmboy.ca/wp-content/uploads/2025/02/FMBOY_0201_GameDay-1.pdf"

    assert flyer.title == "Farm Boy — Game Day"
    assert flyer.store_id == store.id
  end

  test "handles multiple PDF links", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Req.Test.html(conn, """
      <html>
        <body>
          <a href="https://www.farmboy.ca/wp-content/uploads/2025/02/FMBOY_0201_GameDay-1.pdf">Flyer 1</a>
          <a href="https://www.farmboy.ca/wp-content/uploads/2025/02/FMBOY_0208_ValentinesDay-1.pdf">Flyer 2</a>
        </body>
      </html>
      """)
    end)

    {:ok, flyers} = FarmBoy.scrape(store)
    assert length(flyers) == 2

    titles = Enum.map(flyers, & &1.title)
    assert "Farm Boy — Game Day" in titles
    assert "Farm Boy — Valentines Day" in titles
  end

  test "returns empty list when no PDF links found", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Req.Test.html(conn, "<html><body><p>No flyers</p></body></html>")
    end)

    {:ok, flyers} = FarmBoy.scrape(store)
    assert flyers == []
  end

  test "returns error on HTTP failure", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Plug.Conn.send_resp(conn, 503, "Service Unavailable")
    end)

    assert {:error, {:unexpected_status, 503}} = FarmBoy.scrape(store)
  end

  test "falls back to generic title for non-standard URL pattern", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Req.Test.html(conn, """
      <html>
        <body>
          <a href="https://www.farmboy.ca/wp-content/uploads/2025/02/flyer.pdf">Flyer</a>
        </body>
      </html>
      """)
    end)

    {:ok, [flyer]} = FarmBoy.scrape(store)
    assert flyer.title == "Farm Boy Weekly Flyer"
  end
end

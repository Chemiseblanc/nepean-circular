defmodule NepeanCircular.Scraping.FarmersPickTest do
  use NepeanCircular.DataCase

  alias NepeanCircular.Flyers
  alias NepeanCircular.Scraping.FarmersPick

  setup do
    {:ok, store} =
      Flyers.create_store(%{
        name: "Farmer's Pick Test",
        url: "https://www.farmerspick.ca/flyer-specials",
        scraper_module: NepeanCircular.Scraping.FarmersPick
      })

    %{store: store}
  end

  test "extracts PDF links from Squarespace page", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Req.Test.html(conn, """
      <html>
        <body>
          <a href="/s/20250201-weekly-specials.pdf">Weekly Specials</a>
          <a href="/s/20250201-meat-deals.pdf">Meat Deals</a>
          <a href="/other/not-a-flyer.pdf">Other</a>
          <a href="https://external.com/doc.pdf">External</a>
        </body>
      </html>
      """)
    end)

    {:ok, flyers} = FarmersPick.scrape(store)

    assert length(flyers) == 2

    urls = Enum.map(flyers, & &1.pdf_url)
    assert "https://www.farmerspick.ca/s/20250201-weekly-specials.pdf" in urls
    assert "https://www.farmerspick.ca/s/20250201-meat-deals.pdf" in urls

    titles = Enum.map(flyers, & &1.title)
    assert "weekly specials" in titles
    assert "meat deals" in titles

    assert Enum.all?(flyers, &(&1.store_id == store.id))
  end

  test "returns empty list when no PDF links found", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Req.Test.html(conn, "<html><body><p>No flyers this week</p></body></html>")
    end)

    {:ok, flyers} = FarmersPick.scrape(store)
    assert flyers == []
  end

  test "returns error on HTTP failure", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Plug.Conn.send_resp(conn, 500, "Internal Server Error")
    end)

    assert {:error, {:unexpected_status, 500}} = FarmersPick.scrape(store)
  end

  test "strips date prefix from title", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Req.Test.html(conn, """
      <html><body>
        <a href="/s/20250201-fresh-produce.pdf">Flyer</a>
      </body></html>
      """)
    end)

    {:ok, [flyer]} = FarmersPick.scrape(store)
    assert flyer.title == "fresh produce"
  end
end

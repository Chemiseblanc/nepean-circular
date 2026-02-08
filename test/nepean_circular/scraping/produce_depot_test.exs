defmodule NepeanCircular.Scraping.ProduceDepotTest do
  use NepeanCircular.DataCase

  alias NepeanCircular.Flyers
  alias NepeanCircular.Scraping.ProduceDepot

  setup do
    {:ok, store} =
      Flyers.create_store(%{
        name: "Produce Depot Test",
        url: "https://producedepot.ca/weekly-specials/",
        scraper_module: NepeanCircular.Scraping.ProduceDepot
      })

    %{store: store}
  end

  test "extracts PDF from pdfemb viewer element", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Req.Test.html(conn, """
      <html>
        <body>
          <div class="pdfemb-viewer"
               data-pdf-url="https://producedepot.ca/wp-content/uploads/2025/02/weekly.pdf">
          </div>
        </body>
      </html>
      """)
    end)

    {:ok, flyers} = ProduceDepot.scrape(store)

    assert length(flyers) == 1
    assert hd(flyers).pdf_url == "https://producedepot.ca/wp-content/uploads/2025/02/weekly.pdf"
    assert hd(flyers).title == "Weekly Specials"
    assert hd(flyers).store_id == store.id
  end

  test "falls back to direct link URLs", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Req.Test.html(conn, """
      <html>
        <body>
          <a href="https://producedepot.ca/wp-content/uploads/flyer.pdf">Download</a>
        </body>
      </html>
      """)
    end)

    {:ok, flyers} = ProduceDepot.scrape(store)

    assert length(flyers) == 1
    assert hd(flyers).pdf_url == "https://producedepot.ca/wp-content/uploads/flyer.pdf"
  end

  test "falls back to embedded URL regex extraction", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Req.Test.html(conn, """
      <html>
        <body>
          <script>var url="https://producedepot.ca/uploads/weekly.pdf";</script>
        </body>
      </html>
      """)
    end)

    {:ok, flyers} = ProduceDepot.scrape(store)

    assert length(flyers) == 1
    assert hd(flyers).pdf_url == "https://producedepot.ca/uploads/weekly.pdf"
  end

  test "returns empty list when no PDFs found", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Req.Test.html(conn, "<html><body><p>Nothing here</p></body></html>")
    end)

    {:ok, flyers} = ProduceDepot.scrape(store)
    assert flyers == []
  end

  test "returns error on HTTP failure", %{store: store} do
    Req.Test.stub(NepeanCircular.HTTP, fn conn ->
      Plug.Conn.send_resp(conn, 404, "Not Found")
    end)

    assert {:error, {:unexpected_status, 404}} = ProduceDepot.scrape(store)
  end
end

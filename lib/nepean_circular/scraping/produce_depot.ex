defmodule NepeanCircular.Scraping.ProduceDepot do
  @moduledoc """
  Scraper for Produce Depot (WordPress site).

  Finds PDF links embedded via the pdfjs-viewer-shortcode plugin
  or direct `<a>` links to PDF files.
  """

  @behaviour NepeanCircular.Scraping.Scraper

  require Logger

  @impl true
  def scrape(store) do
    case Req.get(store.url, headers: [{"user-agent", user_agent()}]) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        parse_flyers(body, store)

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("ProduceDepot: unexpected status #{status} from #{store.url}")
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        Logger.warning("ProduceDepot: request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_flyers(html, store) do
    {:ok, document} = Floki.parse_document(html)

    # Strategy 1: Look for pdfemb shortcode data attributes
    pdf_urls = extract_pdfemb_urls(document)

    # Strategy 2: Look for direct <a> links to PDFs
    pdf_urls =
      if pdf_urls == [] do
        extract_link_urls(document)
      else
        pdf_urls
      end

    # Strategy 3: Look for iframe/object/embed with PDF src
    pdf_urls =
      if pdf_urls == [] do
        extract_embedded_urls(html)
      else
        pdf_urls
      end

    flyers =
      pdf_urls
      |> Enum.uniq()
      |> Enum.map(fn url ->
        %{
          title: "Weekly Specials",
          pdf_url: ensure_absolute(url, store.url),
          store_id: store.id
        }
      end)

    if flyers == [] do
      Logger.warning("ProduceDepot: no PDF links found on #{store.url}")
    end

    {:ok, flyers}
  end

  defp extract_pdfemb_urls(document) do
    document
    |> Floki.find("[data-pdf-url], .pdfemb-viewer")
    |> Enum.flat_map(fn element ->
      Floki.attribute(element, "data-pdf-url") ++
        Floki.attribute(element, "src")
    end)
    |> Enum.filter(&String.ends_with?(&1, ".pdf"))
  end

  defp extract_link_urls(document) do
    document
    |> Floki.find("a[href$='.pdf']")
    |> Enum.flat_map(fn element -> Floki.attribute(element, "href") end)
  end

  defp extract_embedded_urls(html) do
    Regex.scan(~r/(?:src|url|file)=["']([^"']+\.pdf)["']/i, html)
    |> Enum.map(fn [_, url] -> url end)
  end

  defp ensure_absolute("http" <> _ = url, _base), do: url

  defp ensure_absolute(path, base_url) do
    uri = URI.parse(base_url)
    "#{uri.scheme}://#{uri.host}#{path}"
  end

  defp user_agent do
    "NepeanCircular/1.0 (grocery flyer aggregator)"
  end
end

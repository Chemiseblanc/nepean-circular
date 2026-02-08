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
    case NepeanCircular.HTTP.get_body(store.url) do
      {:ok, body} ->
        {:ok, parse_flyers(body, store)}

      {:error, reason} ->
        Logger.warning("ProduceDepot: failed to fetch #{store.url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_flyers(html, store) do
    {:ok, document} = Floki.parse_document(html)

    pdf_urls =
      extract_pdfemb_urls(document)
      |> then(fn
        [] -> extract_link_urls(document)
        urls -> urls
      end)
      |> then(fn
        [] -> extract_embedded_urls(html)
        urls -> urls
      end)

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

    flyers
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
end

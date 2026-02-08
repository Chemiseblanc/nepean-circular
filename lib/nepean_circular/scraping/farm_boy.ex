defmodule NepeanCircular.Scraping.FarmBoy do
  @moduledoc """
  Scraper for Farm Boy (WordPress site).

  Finds the weekly flyer PDF link on the specials page. The PDF URL
  follows the pattern `wp-content/uploads/YYYY/MM/FMBOY_MMDD_<Theme>-1.pdf`
  where the theme name varies weekly (e.g. "GameDay", "ValentinesDay").

  The PDF is the same for all Farm Boy stores (no region-specific versions).
  """

  @behaviour NepeanCircular.Scraping.Scraper

  require Logger

  @impl true
  def scrape(store) do
    case NepeanCircular.HTTP.get_body(store.url) do
      {:ok, body} ->
        {:ok, parse_flyers(body, store)}

      {:error, reason} ->
        Logger.warning("FarmBoy: failed to fetch #{store.url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_flyers(html, store) do
    {:ok, document} = Floki.parse_document(html)

    flyers =
      document
      |> Floki.find("a[href]")
      |> Enum.flat_map(fn element -> Floki.attribute(element, "href") end)
      |> Enum.filter(&String.contains?(&1, "wp-content/uploads"))
      |> Enum.filter(&String.ends_with?(&1, ".pdf"))
      |> Enum.uniq()
      |> Enum.map(fn url ->
        %{
          title: title_from_url(url),
          pdf_url: url,
          store_id: store.id
        }
      end)

    if flyers == [] do
      Logger.warning("FarmBoy: no PDF links found on #{store.url}")
    end

    flyers
  end

  defp title_from_url(url) do
    url
    |> Path.basename(".pdf")
    |> String.replace("-1", "")
    |> String.split("_")
    |> case do
      [_prefix, _date, theme] -> "Farm Boy — #{humanize_theme(theme)}"
      _ -> "Farm Boy Weekly Flyer"
    end
  end

  defp humanize_theme(theme) do
    theme
    |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")
    |> String.replace(~r/([A-Z]+)([A-Z][a-z])/, "\\1 \\2")
  end
end

defmodule NepeanCircular.Scraping.FarmersPick do
  @moduledoc """
  Scraper for Farmer's Pick (Squarespace site).

  Finds PDF links matching `/s/*.pdf` on the flyer-specials page.
  """

  @behaviour NepeanCircular.Scraping.Scraper

  require Logger

  @impl true
  def scrape(store) do
    case NepeanCircular.HTTP.get_body(store.url) do
      {:ok, body} ->
        {:ok, parse_flyers(body, store)}

      {:error, reason} ->
        Logger.warning("FarmersPick: failed to fetch #{store.url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_flyers(html, store) do
    {:ok, document} = Floki.parse_document(html)

    flyers =
      document
      |> Floki.find("a[href]")
      |> Enum.map(fn element -> Floki.attribute(element, "href") end)
      |> List.flatten()
      |> Enum.filter(&String.ends_with?(&1, ".pdf"))
      |> Enum.filter(&String.starts_with?(&1, "/s/"))
      |> Enum.uniq()
      |> Enum.map(fn path ->
        %{
          title: title_from_path(path),
          pdf_url: "https://www.farmerspick.ca" <> path,
          store_id: store.id
        }
      end)

    if flyers == [] do
      Logger.warning("FarmersPick: no PDF links found on #{store.url}")
    end

    flyers
  end

  defp title_from_path(path) do
    path
    |> Path.basename(".pdf")
    |> String.replace("-", " ")
    |> String.replace(~r/^\d{8}\s*/, "")
    |> then(fn
      "" -> "Weekly Flyer"
      name -> name
    end)
  end
end

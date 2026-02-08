defmodule NepeanCircular.Scraping.FarmersPick do
  @moduledoc """
  Scraper for Farmer's Pick (Squarespace site).

  Finds PDF links matching `/s/*.pdf` on the flyer-specials page.
  """

  @behaviour NepeanCircular.Scraping.Scraper

  require Logger

  @impl true
  def scrape(store) do
    case Req.get(store.url, headers: [{"user-agent", user_agent()}]) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        parse_flyers(body, store)

      {:ok, %Req.Response{status: status}} ->
        Logger.warning("FarmersPick: unexpected status #{status} from #{store.url}")
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        Logger.warning("FarmersPick: request failed: #{inspect(reason)}")
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
        pdf_url = "https://www.farmerspick.ca" <> path
        title = title_from_path(path)

        %{
          title: title,
          pdf_url: pdf_url,
          store_id: store.id
        }
      end)

    if flyers == [] do
      Logger.warning("FarmersPick: no PDF links found on #{store.url}")
    end

    {:ok, flyers}
  end

  defp title_from_path(path) do
    path
    |> Path.basename(".pdf")
    |> String.replace("-", " ")
    |> String.replace(~r/^\d{8}\s*/, "")
    |> then(fn name ->
      if name == "", do: "Weekly Flyer", else: name
    end)
  end

  defp user_agent do
    "NepeanCircular/1.0 (grocery flyer aggregator)"
  end
end

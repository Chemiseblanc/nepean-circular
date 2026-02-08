defmodule NepeanCircular.Scraping.GreenFresh do
  @moduledoc """
  Scraper for Green Fresh Ottawa (Wix site).

  This store publishes flyer pages as PNG images rather than a PDF.
  We extract the image URLs, download them, and convert to a single
  PDF using Pillow via Pythonx.
  """

  @behaviour NepeanCircular.Scraping.Scraper

  require Logger

  @impl true
  def scrape(store) do
    case NepeanCircular.HTTP.get_body(store.url) do
      {:ok, body} ->
        body
        |> extract_flyer_images()
        |> build_flyer(store)

      {:error, reason} ->
        Logger.warning("GreenFresh: failed to fetch #{store.url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_flyer([], _store) do
    Logger.warning("GreenFresh: no flyer images found")
    {:ok, []}
  end

  defp build_flyer(image_urls, store) do
    case NepeanCircular.Pdf.images_to_pdf(image_urls, "green_fresh") do
      {:ok, pdf_path} ->
        {:ok,
         [
           %{
             title: "Green Fresh Weekly Flyer",
             pdf_url: "file://#{pdf_path}",
             store_id: store.id
           }
         ]}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Extracts flyer image URLs from the Wix page HTML.

  Wix uses `q_90` quality for content images (flyers) vs `q_80` for
  decorative images. We extract unique media IDs from large images,
  then build full-resolution download URLs.
  """
  def extract_flyer_images(html) do
    ~r{static\.wixstatic\.com/media/(61ee79_[a-f0-9]+~mv2\.png)/v1/fill/w_(\d+),h_(\d+),q_90}
    |> Regex.scan(html)
    |> Enum.map(fn [_, media_id, w, h] ->
      {media_id, String.to_integer(w), String.to_integer(h)}
    end)
    |> Enum.group_by(fn {id, _w, _h} -> id end)
    |> Enum.map(fn {_id, variants} ->
      Enum.max_by(variants, fn {_id, w, h} -> w * h end)
    end)
    |> Enum.filter(fn {_id, w, h} -> w >= 500 and h >= 500 end)
    |> Enum.sort_by(fn {_id, w, _h} -> w end)
    |> Enum.map(fn {media_id, w, h} ->
      "https://static.wixstatic.com/media/#{media_id}/v1/fill/w_#{w},h_#{h},q_90/#{media_id}"
    end)
  end
end

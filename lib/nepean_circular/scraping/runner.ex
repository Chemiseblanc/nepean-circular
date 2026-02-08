defmodule NepeanCircular.Scraping do
  @moduledoc """
  Runs scrapers and persists discovered flyers.
  """

  require Logger

  alias NepeanCircular.Flyers

  @doc """
  Scrape flyers for a single store using its configured scraper_module.
  Returns `{:ok, count}` with the number of new flyers created.
  """
  def run(store) do
    scraper = store.scraper_module
    Logger.info("Scraping #{store.name} with #{inspect(scraper)}")

    case scraper.scrape(store) do
      {:ok, flyer_attrs_list} ->
        results =
          Enum.map(flyer_attrs_list, fn attrs ->
            case Flyers.create_flyer(attrs) do
              {:ok, flyer} ->
                Logger.info("Upserted flyer: #{flyer.title} (#{flyer.pdf_url})")
                {:ok, flyer}

              {:error, error} ->
                Logger.warning("Failed to create flyer: #{inspect(error)}")
                {:error, error}
            end
          end)

        new_count = Enum.count(results, &match?({:ok, _}, &1))
        Logger.info("Scrape complete for #{store.name}: #{new_count} flyer(s)")
        {:ok, new_count}

      {:error, reason} ->
        Logger.warning("Scrape failed for #{store.name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Scrape all active stores, then regenerate the combined PDF.
  """
  def run_all do
    case Flyers.list_stores() do
      {:ok, stores} ->
        results =
          stores
          |> Enum.filter(& &1.active)
          |> Enum.map(fn store ->
            {store.name, run(store)}
          end)

        NepeanCircular.Pdf.generate_combined()

        results

      {:error, reason} ->
        Logger.warning("Failed to list stores: #{inspect(reason)}")
        {:error, reason}
    end
  end
end

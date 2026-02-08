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
                Logger.info("Created flyer: #{flyer.title} (#{flyer.pdf_url})")
                {:ok, flyer}

              {:error, %Ash.Error.Invalid{} = error} ->
                if has_unique_constraint_error?(error) do
                  Logger.debug("Flyer already exists: #{attrs.pdf_url}")
                  :exists
                else
                  Logger.warning("Failed to create flyer: #{inspect(error)}")
                  {:error, error}
                end

              {:error, error} ->
                Logger.warning("Failed to create flyer: #{inspect(error)}")
                {:error, error}
            end
          end)

        new_count = Enum.count(results, &match?({:ok, _}, &1))
        Logger.info("Scrape complete for #{store.name}: #{new_count} new flyer(s)")
        {:ok, new_count}

      {:error, reason} ->
        Logger.warning("Scrape failed for #{store.name}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Scrape all active stores.
  """
  def run_all do
    case Flyers.list_stores() do
      {:ok, stores} ->
        stores
        |> Enum.filter(& &1.active)
        |> Enum.map(fn store ->
          {store.name, run(store)}
        end)

      {:error, reason} ->
        Logger.warning("Failed to list stores: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp has_unique_constraint_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.InvalidChanges{message: msg} ->
        String.contains?(to_string(msg), "unique")

      _ ->
        false
    end)
  end
end

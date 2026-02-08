defmodule NepeanCircular.Workers.InitialScrape do
  @moduledoc """
  Oban worker that performs the first-time flyer scrape on application startup.

  This is separate from the recurring `ScrapeFlyers` cron job. It runs once when
  the app boots and no combined PDF exists yet, ensuring flyers are available
  immediately rather than waiting for the next scheduled scrape.

  The job uses `unique` to prevent duplicate runs if the app restarts quickly.
  """

  use Oban.Worker, queue: :scraping, max_attempts: 3, unique: [period: 300]

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    if NepeanCircular.Pdf.combined_pdf_exists?() do
      Logger.info("Combined PDF already exists, skipping initial scrape")
      :ok
    else
      Logger.info("No combined PDF found — running initial flyer scrape")

      case NepeanCircular.Scraping.run_all() do
        results when is_list(results) ->
          Logger.info("Initial scrape results: #{inspect(results)}")
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end
  end
end

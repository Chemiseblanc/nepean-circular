defmodule NepeanCircular.Workers.InitialScrape do
  @moduledoc """
  Oban worker that performs a flyer scrape on application startup.

  This always runs on boot to ensure the combined PDF reflects the latest
  scraping and generation logic. Old PDFs are cleaned before regenerating.

  The job uses `unique` to prevent duplicate runs if the app restarts quickly.
  """

  use Oban.Worker, queue: :scraping, max_attempts: 3, unique: [period: 300]

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    NepeanCircular.Pdf.clean_generated_pdfs()
    Logger.info("Cleaned old PDFs — seeding stores and running scrape")
    NepeanCircular.Release.seed_stores()

    case NepeanCircular.Scraping.run_all() do
      results when is_list(results) ->
        Logger.info("Initial scrape results: #{inspect(results)}")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end

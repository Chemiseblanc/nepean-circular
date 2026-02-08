defmodule NepeanCircular.Workers.ScrapeFlyers do
  @moduledoc """
  Oban worker that scrapes flyers for all active stores.
  """

  use Oban.Worker, queue: :scraping, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Starting scheduled flyer scrape")

    case NepeanCircular.Scraping.run_all() do
      results when is_list(results) ->
        Logger.info("Scrape results: #{inspect(results)}")
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end

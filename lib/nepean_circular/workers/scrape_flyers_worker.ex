defmodule NepeanCircular.Workers.ScrapeFlyers do
  @moduledoc """
  Oban worker that scrapes flyers for all active stores.
  """

  use Oban.Worker, queue: :scraping, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Phoenix.PubSub.broadcast(NepeanCircular.PubSub, "scraping", :scrape_started)
    Logger.info("Starting scheduled flyer scrape")

    result =
      case NepeanCircular.Scraping.run_all() do
        results when is_list(results) ->
          Logger.info("Scrape results: #{inspect(results)}")
          :ok

        {:error, reason} ->
          {:error, reason}
      end

    Phoenix.PubSub.broadcast(NepeanCircular.PubSub, "scraping", :scrape_finished)
    result
  end
end

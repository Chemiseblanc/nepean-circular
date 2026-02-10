defmodule NepeanCircular.Workers.ScrapeFlyers do
  @moduledoc """
  Oban worker that scrapes flyers for all active stores.

  After a successful scrape on the configured email day (Thursday by default),
  enqueues `SendFlyerEmails` so weekly emails are only sent once the new
  combined PDF is ready.
  """

  use Oban.Worker, queue: :scraping, max_attempts: 3

  require Logger

  # Day of the week to send the weekly flyer email (4 = Thursday).
  @email_day_of_week 4

  @impl Oban.Worker
  def perform(_job) do
    Phoenix.PubSub.broadcast(NepeanCircular.PubSub, "scraping", :scrape_started)
    Logger.info("Starting scheduled flyer scrape")

    result =
      case NepeanCircular.Scraping.run_all() do
        results when is_list(results) ->
          Logger.info("Scrape results: #{inspect(results)}")
          maybe_enqueue_emails()
          :ok

        {:error, reason} ->
          {:error, reason}
      end

    Phoenix.PubSub.broadcast(NepeanCircular.PubSub, "scraping", :scrape_finished)
    result
  end

  # Enqueues the weekly flyer email job if today is the configured email day.
  defp maybe_enqueue_emails do
    if Date.day_of_week(Date.utc_today()) == @email_day_of_week do
      Logger.info("Scrape complete on email day — enqueuing weekly flyer emails")
      %{} |> NepeanCircular.Workers.SendFlyerEmails.new() |> Oban.insert()
    end
  end
end

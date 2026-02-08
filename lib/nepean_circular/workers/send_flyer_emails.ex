defmodule NepeanCircular.Workers.SendFlyerEmails do
  use Oban.Worker, queue: :default

  alias NepeanCircular.{Emails, Flyers, Mailer, Pdf}

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    unless Pdf.combined_pdf_exists?() do
      Logger.info("No combined PDF available, skipping email send")
      :ok
    else
      case Flyers.list_active_subscribers() do
        {:ok, []} ->
          Logger.info("No active subscribers, skipping email send")
          :ok

        {:ok, subscribers} ->
          Logger.info("Sending weekly flyer to #{length(subscribers)} subscribers")

          Enum.each(subscribers, fn subscriber ->
            subscriber
            |> Emails.weekly_flyer()
            |> Mailer.deliver()
            |> case do
              {:ok, _} ->
                Logger.debug("Sent flyer to #{subscriber.email}")

              {:error, reason} ->
                Logger.error("Failed to send flyer to #{subscriber.email}: #{inspect(reason)}")
            end
          end)

          :ok
      end
    end
  end
end

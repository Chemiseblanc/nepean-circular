defmodule NepeanCircular.Workers.SendWelcomeEmail do
  use Oban.Worker,
    queue: :default,
    unique: [keys: [:subscriber_id], states: [:available, :scheduled, :executing]]

  alias NepeanCircular.{Emails, Flyers, Mailer, Pdf}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"subscriber_id" => subscriber_id}}) do
    with {:ok, subscriber} <- Flyers.get_subscriber(subscriber_id),
         true <- is_nil(subscriber.welcomed_at),
         true <- Pdf.combined_pdf_exists?() do
      subscriber
      |> Emails.weekly_flyer()
      |> Mailer.deliver()
      |> case do
        {:ok, _} ->
          Logger.info("Sent welcome email to #{subscriber.email}")
          Flyers.mark_welcomed(subscriber)
          :ok

        {:error, reason} ->
          Logger.error("Failed to send welcome email to #{subscriber.email}: #{inspect(reason)}")
          {:error, reason}
      end
    else
      {:error, %Ash.Error.Query.NotFound{}} ->
        Logger.warning("Subscriber #{subscriber_id} not found, skipping welcome email")
        :ok

      false ->
        Logger.debug("Skipping welcome email: subscriber already welcomed or no PDF available")
        :ok
    end
  end
end

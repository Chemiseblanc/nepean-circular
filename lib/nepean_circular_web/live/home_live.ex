defmodule NepeanCircularWeb.HomeLive do
  use NepeanCircularWeb, :live_view

  alias NepeanCircular.{Flyers, Pdf}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Weekly Flyers")
     |> assign(:has_combined_pdf, Pdf.combined_pdf_exists?())
     |> assign(:combined_pdf_path, Pdf.combined_pdf_path())
     |> assign(:subscribe_form, to_form(%{"email" => ""}, as: :subscriber))}
  end

  @impl true
  def handle_event("subscribe", %{"subscriber" => %{"email" => email}}, socket) do
    case Flyers.subscribe(%{email: email}) do
      {:ok, subscriber} ->
        if is_nil(subscriber.welcomed_at) do
          %{"subscriber_id" => subscriber.id}
          |> NepeanCircular.Workers.SendWelcomeEmail.new()
          |> Oban.insert()
        end

        flash =
          if is_nil(subscriber.welcomed_at) && Pdf.combined_pdf_exists?() do
            "You're subscribed! Check your inbox for this week's flyers."
          else
            "You're subscribed! You'll receive weekly flyers every Thursday."
          end

        {:noreply,
         socket
         |> put_flash(:info, flash)
         |> assign(:subscribe_form, to_form(%{"email" => ""}, as: :subscriber))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Please enter a valid email address.")}
    end
  end
end

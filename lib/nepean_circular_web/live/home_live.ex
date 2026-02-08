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
      {:ok, _subscriber} ->
        {:noreply,
         socket
         |> put_flash(:info, "You're subscribed! You'll receive weekly flyers every Thursday.")
         |> assign(:subscribe_form, to_form(%{"email" => ""}, as: :subscriber))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Please enter a valid email address.")}
    end
  end
end

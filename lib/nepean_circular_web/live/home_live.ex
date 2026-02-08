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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="text-center space-y-2">
          <h1 class="text-3xl font-bold">Nepean Circular</h1>
          <p class="text-base-content/70">This week's local grocery flyers — all in one place</p>
        </div>

        <div class="max-w-md mx-auto">
          <.form
            for={@subscribe_form}
            id="subscribe-form"
            phx-submit="subscribe"
            class="flex gap-2 items-end"
          >
            <div class="flex-1">
              <.input
                field={@subscribe_form[:email]}
                type="email"
                label="Get flyers by email"
                placeholder="you@example.com"
                autocomplete="email"
                required
              />
            </div>
            <.button type="submit" class="mb-1">
              Subscribe
            </.button>
          </.form>
        </div>

        <div :if={@has_combined_pdf} class="space-y-4">
          <div class="flex justify-end">
            <a
              href={@combined_pdf_path}
              download="weekly-flyers.pdf"
              class="btn btn-primary btn-sm"
            >
              Download Combined PDF ↓
            </a>
          </div>

          <div class="w-full rounded-lg overflow-hidden border border-base-300" style="height: 85vh;">
            <iframe
              src={@combined_pdf_path}
              class="w-full h-full"
              title="Combined weekly flyers"
            >
            </iframe>
          </div>
        </div>

        <div :if={!@has_combined_pdf} class="text-center py-20 space-y-4">
          <p class="text-lg text-base-content/60">No combined flyer available yet.</p>
          <p class="text-sm text-base-content/40">Flyers are scraped and combined daily.</p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

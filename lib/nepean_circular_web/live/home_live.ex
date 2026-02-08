defmodule NepeanCircularWeb.HomeLive do
  use NepeanCircularWeb, :live_view

  alias NepeanCircular.Flyers

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stores} = Flyers.list_stores()

    stores_with_flyers =
      stores
      |> Enum.filter(& &1.active)
      |> Enum.map(fn store ->
        current_flyer =
          case Flyers.current_flyer_for_store(store.id) do
            {:ok, [flyer | _]} -> flyer
            _ -> nil
          end

        {store, current_flyer}
      end)

    {:ok,
     socket
     |> assign(:page_title, "Local Flyers")
     |> assign(:stores_with_flyers, stores_with_flyers)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-8">
        <div class="text-center space-y-2">
          <h1 class="text-3xl font-bold">Nepean Circular</h1>
          <p class="text-base-content/70">Your local grocery flyers in one place</p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div
            :for={{store, flyer} <- @stores_with_flyers}
            class="card bg-base-200 shadow-md"
          >
            <div class="card-body">
              <h2 class="card-title">{store.name}</h2>
              <p :if={flyer} class="text-sm text-base-content/60">
                {flyer.title}
              </p>
              <p :if={!flyer} class="text-sm text-base-content/60">
                No flyer available
              </p>
              <div class="card-actions justify-end mt-4">
                <.link
                  :if={flyer}
                  navigate={~p"/stores/#{store.id}"}
                  class="btn btn-primary btn-sm"
                >
                  View Flyer
                </.link>
                <a
                  :if={flyer}
                  href={flyer.pdf_url}
                  target="_blank"
                  rel="noopener"
                  class="btn btn-ghost btn-sm"
                >
                  Download PDF
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

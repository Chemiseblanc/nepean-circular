defmodule NepeanCircularWeb.StoreLive do
  use NepeanCircularWeb, :live_view

  alias NepeanCircular.Flyers

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Flyers.get_store(id) do
      {:ok, store} ->
        {:ok, flyers} = Flyers.list_flyers()

        store_flyers =
          flyers
          |> Enum.filter(&(&1.store_id == store.id))
          |> Enum.sort_by(& &1.scraped_at, {:desc, DateTime})

        current_flyer = List.first(store_flyers)

        {:ok,
         socket
         |> assign(:page_title, store.name)
         |> assign(:store, store)
         |> assign(:flyers, store_flyers)
         |> assign(:current_flyer, current_flyer)}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-6">
        <div class="flex items-center gap-4">
          <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
            ← Back
          </.link>
          <h1 class="text-2xl font-bold">{@store.name}</h1>
        </div>

        <div :if={@current_flyer} class="space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold">{@current_flyer.title}</h2>
            <a
              href={@current_flyer.pdf_url}
              target="_blank"
              rel="noopener"
              class="btn btn-primary btn-sm"
            >
              Open PDF ↗
            </a>
          </div>

          <div class="w-full rounded-lg overflow-hidden border border-base-300" style="height: 80vh;">
            <iframe
              src={@current_flyer.pdf_url}
              class="w-full h-full"
              title={"#{@store.name} flyer"}
            >
            </iframe>
          </div>
        </div>

        <div :if={!@current_flyer} class="text-center py-12">
          <p class="text-base-content/60">No flyer available for this store yet.</p>
        </div>

        <div :if={length(@flyers) > 1} class="space-y-2">
          <h3 class="text-lg font-semibold">Previous Flyers</h3>
          <ul class="space-y-1">
            <li :for={flyer <- tl(@flyers)} class="flex items-center justify-between py-2 px-3 rounded bg-base-200">
              <span>{flyer.title}</span>
              <a href={flyer.pdf_url} target="_blank" rel="noopener" class="link link-primary text-sm">
                View PDF
              </a>
            </li>
          </ul>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

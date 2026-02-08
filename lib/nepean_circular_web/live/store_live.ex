defmodule NepeanCircularWeb.StoreLive do
  use NepeanCircularWeb, :live_view

  alias NepeanCircular.Flyers

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Flyers.get_store(id) do
      {:ok, store} ->
        current_flyer =
          case Flyers.current_flyer_for_store(store.id) do
            {:ok, [flyer | _]} -> flyer
            _ -> nil
          end

        {:ok,
         socket
         |> assign(:page_title, store.name)
         |> assign(:store, store)
         |> assign(:current_flyer, current_flyer)
         |> assign(:flyer_url, viewable_url(current_flyer))}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Store not found")
         |> push_navigate(to: ~p"/")}
    end
  end

  # file:// URLs can't be displayed in browser iframes — serve via controller instead
  defp viewable_url(nil), do: nil
  defp viewable_url(%{pdf_url: "file://" <> _}), do: nil
  defp viewable_url(%{pdf_url: url}), do: url

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

        <div :if={@current_flyer && @flyer_url} class="space-y-4">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold">{@current_flyer.title}</h2>
            <a
              href={@flyer_url}
              target="_blank"
              rel="noopener"
              class="btn btn-primary btn-sm"
            >
              Open PDF ↗
            </a>
          </div>

          <div class="w-full rounded-lg overflow-hidden border border-base-300" style="height: 80vh;">
            <iframe
              src={@flyer_url}
              class="w-full h-full"
              title={"#{@store.name} flyer"}
            >
            </iframe>
          </div>
        </div>

        <div :if={@current_flyer && !@flyer_url} class="text-center py-12 space-y-2">
          <p class="text-base-content/70">{@current_flyer.title}</p>
          <p class="text-sm text-base-content/40">
            This flyer is included in the combined PDF on the homepage.
          </p>
          <.link navigate={~p"/"} class="btn btn-primary btn-sm">
            View Combined Flyers
          </.link>
        </div>

        <div :if={!@current_flyer} class="text-center py-12">
          <p class="text-base-content/60">No flyer available for this store yet.</p>
        </div>
      </div>
    </Layouts.app>
    """
  end
end

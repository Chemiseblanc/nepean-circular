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
end

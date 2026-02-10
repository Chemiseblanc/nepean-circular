defmodule NepeanCircularWeb.PageController do
  use NepeanCircularWeb, :controller

  alias NepeanCircular.{Flyers, Pdf}

  def home(conn, _params) do
    conn
    |> assign(:page_title, "Weekly Flyers")
    |> assign(:has_combined_pdf, Pdf.combined_pdf_exists?())
    |> assign(:combined_pdf_path, Pdf.combined_pdf_path())
    |> assign(:scraping?, scraping_in_progress?())
    |> assign(:subscribe_form, Phoenix.Component.to_form(%{"email" => ""}, as: :subscriber))
    |> render(:home)
  end

  def subscribe(conn, %{"subscriber" => %{"email" => email}}) do
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

        conn
        |> put_flash(:info, flash)
        |> redirect(to: ~p"/")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Please enter a valid email address.")
        |> redirect(to: ~p"/")
    end
  end

  defp scraping_in_progress? do
    import Ecto.Query

    NepeanCircular.Repo.exists?(
      from j in Oban.Job,
        where: j.queue == "scraping" and j.state in ["executing", "available"]
    )
  end
end

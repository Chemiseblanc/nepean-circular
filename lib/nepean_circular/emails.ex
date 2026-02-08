defmodule NepeanCircular.Emails do
  import Swoosh.Email

  alias NepeanCircular.Pdf

  @from {"Nepean Circular", "flyers@nepean-circular.com"}

  def weekly_flyer(%{email: email, token: token}) do
    unsubscribe_url = NepeanCircularWeb.Endpoint.url() <> "/unsubscribe?token=#{token}"

    email =
      new()
      |> to(email)
      |> from(@from)
      |> subject("This Week's Grocery Flyers")
      |> header("List-Unsubscribe", "<#{unsubscribe_url}>")
      |> header("List-Unsubscribe-Post", "List-Unsubscribe=One-Click")
      |> html_body(html_body(unsubscribe_url))
      |> text_body(text_body(unsubscribe_url))

    pdf_path = Pdf.combined_pdf_file()

    if File.exists?(pdf_path) do
      attachment(email, Swoosh.Attachment.new(pdf_path, filename: "weekly-flyers.pdf"))
    else
      email
    end
  end

  defp html_body(unsubscribe_url) do
    """
    <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
      <h1 style="color: #1a1a1a;">This Week's Grocery Flyers</h1>
      <p>Your combined weekly grocery flyers are attached as a PDF.</p>
      <p style="margin-top: 24px;">
        <a href="#{NepeanCircularWeb.Endpoint.url()}"
           style="background: #2563eb; color: white; padding: 10px 20px; border-radius: 6px; text-decoration: none;">
          View Online
        </a>
      </p>
      <hr style="margin-top: 32px; border: none; border-top: 1px solid #e5e5e5;" />
      <p style="font-size: 12px; color: #888;">
        <a href="#{unsubscribe_url}" style="color: #888;">Unsubscribe</a>
      </p>
    </div>
    """
  end

  defp text_body(unsubscribe_url) do
    """
    This Week's Grocery Flyers

    Your combined weekly grocery flyers are attached as a PDF.

    View online: #{NepeanCircularWeb.Endpoint.url()}

    Unsubscribe: #{unsubscribe_url}
    """
  end
end

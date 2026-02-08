defmodule NepeanCircular.EmailsTest do
  use ExUnit.Case

  alias NepeanCircular.Emails

  describe "weekly_flyer/1" do
    test "builds email with correct to, from, and subject" do
      email = Emails.weekly_flyer(%{email: "user@example.com", token: "test-token-123"})

      assert email.to == [{"", "user@example.com"}]
      assert email.subject == "This Week's Grocery Flyers"
    end

    test "includes List-Unsubscribe header with token URL" do
      email = Emails.weekly_flyer(%{email: "user@example.com", token: "abc123"})

      unsubscribe_header =
        Enum.find(email.headers, fn {key, _} -> key == "List-Unsubscribe" end)

      assert unsubscribe_header != nil
      {_, value} = unsubscribe_header
      assert value =~ "token=abc123"
      assert value =~ "/unsubscribe"
    end

    test "includes List-Unsubscribe-Post header for one-click RFC 8058" do
      email = Emails.weekly_flyer(%{email: "user@example.com", token: "abc123"})

      post_header =
        Enum.find(email.headers, fn {key, _} -> key == "List-Unsubscribe-Post" end)

      assert post_header == {"List-Unsubscribe-Post", "List-Unsubscribe=One-Click"}
    end

    test "HTML body contains unsubscribe link" do
      email = Emails.weekly_flyer(%{email: "user@example.com", token: "mytoken"})

      assert email.html_body =~ "unsubscribe"
      assert email.html_body =~ "token=mytoken"
    end

    test "text body contains unsubscribe link" do
      email = Emails.weekly_flyer(%{email: "user@example.com", token: "mytoken"})

      assert email.text_body =~ "Unsubscribe"
      assert email.text_body =~ "token=mytoken"
    end
  end
end

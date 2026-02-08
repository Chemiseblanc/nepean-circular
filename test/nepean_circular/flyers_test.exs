defmodule NepeanCircular.FlyersTest do
  use NepeanCircular.DataCase

  alias NepeanCircular.Flyers

  describe "subscriber lifecycle" do
    test "subscribe creates a subscriber with email and token" do
      {:ok, subscriber} = Flyers.subscribe(%{email: "test@example.com"})

      assert subscriber.email == "test@example.com"
      assert subscriber.token != nil
      assert byte_size(subscriber.token) > 0
      assert subscriber.unsubscribed_at == nil
    end

    test "subscribe with duplicate email upserts without error" do
      {:ok, first} = Flyers.subscribe(%{email: "dupe@example.com"})
      {:ok, second} = Flyers.subscribe(%{email: "dupe@example.com"})

      assert first.id == second.id
      assert first.token == second.token
    end

    test "unsubscribe sets unsubscribed_at" do
      {:ok, subscriber} = Flyers.subscribe(%{email: "unsub@example.com"})
      assert subscriber.unsubscribed_at == nil

      {:ok, unsubbed} = Flyers.unsubscribe(subscriber)
      assert unsubbed.unsubscribed_at != nil
    end

    test "list_active_subscribers excludes unsubscribed" do
      {:ok, active} = Flyers.subscribe(%{email: "active@example.com"})
      {:ok, to_unsub} = Flyers.subscribe(%{email: "gone@example.com"})
      Flyers.unsubscribe(to_unsub)

      {:ok, subscribers} = Flyers.list_active_subscribers()
      emails = Enum.map(subscribers, & &1.email)

      assert active.email in emails
      refute "gone@example.com" in emails
    end

    test "get_subscriber_by_token returns correct subscriber" do
      {:ok, subscriber} = Flyers.subscribe(%{email: "token@example.com"})

      {:ok, [found]} = Flyers.get_subscriber_by_token(subscriber.token)
      assert found.id == subscriber.id
    end

    test "get_subscriber_by_token returns empty for invalid token" do
      {:ok, []} = Flyers.get_subscriber_by_token("nonexistent-token")
    end
  end

  describe "store and flyer basics" do
    test "create store and flyer" do
      {:ok, store} =
        Flyers.create_store(%{
          name: "Test Store",
          url: "https://example.com",
          scraper_module: NepeanCircular.Scraping.FarmersPick
        })

      assert store.name == "Test Store"

      {:ok, flyer} =
        Flyers.create_flyer(%{
          title: "Weekly Flyer",
          pdf_url: "https://example.com/flyer.pdf",
          store_id: store.id
        })

      assert flyer.title == "Weekly Flyer"
      assert flyer.pdf_url == "https://example.com/flyer.pdf"
    end

    test "flyer upsert on duplicate pdf_url updates title" do
      {:ok, store} =
        Flyers.create_store(%{
          name: "Upsert Store",
          url: "https://example.com",
          scraper_module: NepeanCircular.Scraping.FarmersPick
        })

      {:ok, first} =
        Flyers.create_flyer(%{
          title: "Original Title",
          pdf_url: "https://example.com/same.pdf",
          store_id: store.id
        })

      {:ok, second} =
        Flyers.create_flyer(%{
          title: "Updated Title",
          pdf_url: "https://example.com/same.pdf",
          store_id: store.id
        })

      assert first.id == second.id
      assert second.title == "Updated Title"
    end

    test "current_flyer_for_store returns most recent" do
      {:ok, store} =
        Flyers.create_store(%{
          name: "Recent Store",
          url: "https://example.com",
          scraper_module: NepeanCircular.Scraping.FarmersPick
        })

      {:ok, _old} =
        Flyers.create_flyer(%{
          title: "Old Flyer",
          pdf_url: "https://example.com/old.pdf",
          store_id: store.id
        })

      {:ok, newer} =
        Flyers.create_flyer(%{
          title: "New Flyer",
          pdf_url: "https://example.com/new.pdf",
          store_id: store.id
        })

      {:ok, [current]} = Flyers.current_flyer_for_store(store.id)
      assert current.id == newer.id
    end
  end
end

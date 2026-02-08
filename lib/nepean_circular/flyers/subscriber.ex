defmodule NepeanCircular.Flyers.Subscriber do
  use Ash.Resource,
    domain: NepeanCircular.Flyers,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table("subscribers")
    repo(NepeanCircular.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:email, :string, allow_nil?: false, public?: true)

    attribute(:token, :string,
      allow_nil?: false,
      public?: false,
      default: &NepeanCircular.Flyers.Subscriber.generate_token/0
    )

    attribute(:unsubscribed_at, :utc_datetime, public?: false)
    timestamps()
  end

  actions do
    defaults([:read])

    create :subscribe do
      accept([:email])
      upsert?(true)
      upsert_identity(:unique_email)
      upsert_fields([:updated_at])
    end

    update :unsubscribe do
      accept([])
      change(set_attribute(:unsubscribed_at, &DateTime.utc_now/0))
    end

    read :active do
      filter(expr(is_nil(unsubscribed_at)))
    end

    read :by_token do
      argument(:token, :string, allow_nil?: false)
      filter(expr(token == ^arg(:token)))
    end
  end

  identities do
    identity(:unique_email, [:email])
  end

  def generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end

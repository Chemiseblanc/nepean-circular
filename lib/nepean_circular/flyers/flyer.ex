defmodule NepeanCircular.Flyers.Flyer do
  use Ash.Resource,
    domain: NepeanCircular.Flyers,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table("flyers")
    repo(NepeanCircular.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:title, :string, allow_nil?: false, public?: true)
    attribute(:pdf_url, :string, allow_nil?: false, public?: true)
    attribute(:valid_from, :date, public?: true)
    attribute(:valid_to, :date, public?: true)
    create_timestamp(:scraped_at)
    timestamps()
  end

  relationships do
    belongs_to :store, NepeanCircular.Flyers.Store, allow_nil?: false
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:title, :pdf_url, :valid_from, :valid_to])
      argument(:store_id, :uuid, allow_nil?: false)
      change(manage_relationship(:store_id, :store, type: :append))
      upsert?(true)
      upsert_identity(:unique_pdf_url)
      upsert_fields([:title])
    end

    read :current_for_store do
      argument(:store_id, :uuid, allow_nil?: false)
      filter(expr(store_id == ^arg(:store_id)))
      prepare(build(sort: [scraped_at: :desc], limit: 1))
    end
  end

  identities do
    identity(:unique_pdf_url, [:pdf_url])
  end
end

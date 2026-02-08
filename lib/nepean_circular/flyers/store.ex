defmodule NepeanCircular.Flyers.Store do
  use Ash.Resource,
    domain: NepeanCircular.Flyers,
    data_layer: AshSqlite.DataLayer

  sqlite do
    table "stores"
    repo NepeanCircular.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :name, :string, allow_nil?: false, public?: true
    attribute :url, :string, allow_nil?: false, public?: true
    attribute :scraper_module, :atom, allow_nil?: false, public?: true
    attribute :logo_url, :string, public?: true
    attribute :active, :boolean, default: true, public?: true
    timestamps()
  end

  relationships do
    has_many :flyers, NepeanCircular.Flyers.Flyer
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:name, :url, :scraper_module, :logo_url, :active]
    end

    update :update do
      accept [:name, :url, :scraper_module, :logo_url, :active]
    end
  end
end

defmodule NepeanCircular.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :nepean_circular

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Seeds the database with the default set of stores.
  Uses upsert so it is safe to call multiple times.
  """
  def seed_stores do
    stores = [
      %{
        name: "Farmer's Pick",
        url: "https://www.farmerspick.ca/flyer-specials",
        scraper_module: NepeanCircular.Scraping.FarmersPick,
        active: true
      },
      %{
        name: "Produce Depot",
        url: "https://producedepot.ca/weekly-specials/",
        scraper_module: NepeanCircular.Scraping.ProduceDepot,
        active: true
      },
      %{
        name: "Farm Boy",
        url: "https://www.farmboy.ca/weekly-flyer-specials/",
        scraper_module: NepeanCircular.Scraping.FarmBoy,
        active: true
      },
      %{
        name: "Green Fresh",
        url: "https://greenfreshottawa20.wixsite.com/greenfreshottawa/services-4-1",
        scraper_module: NepeanCircular.Scraping.GreenFresh,
        active: true
      }
    ]

    for attrs <- stores do
      NepeanCircular.Flyers.create_store(attrs)
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end

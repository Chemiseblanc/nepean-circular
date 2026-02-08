# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs

alias NepeanCircular.Flyers

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
  case Flyers.create_store(attrs) do
    {:ok, store} -> IO.puts("Created store: #{store.name}")
    {:error, error} -> IO.puts("Error creating #{attrs.name}: #{inspect(error)}")
  end
end

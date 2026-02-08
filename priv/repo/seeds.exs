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
  }
]

for attrs <- stores do
  case Flyers.create_store(attrs) do
    {:ok, store} -> IO.puts("Created store: #{store.name}")
    {:error, error} -> IO.puts("Error creating #{attrs.name}: #{inspect(error)}")
  end
end

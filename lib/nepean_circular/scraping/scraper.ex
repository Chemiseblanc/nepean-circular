defmodule NepeanCircular.Scraping.Scraper do
  @moduledoc """
  Behaviour for store-specific flyer scrapers.

  Each implementation fetches a single page and extracts flyer PDF URLs.
  """

  @callback scrape(store :: struct()) :: {:ok, [map()]} | {:error, term()}
end

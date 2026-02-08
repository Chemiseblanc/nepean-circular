defmodule NepeanCircular.Flyers do
  use Ash.Domain

  resources do
    resource NepeanCircular.Flyers.Store do
      define :list_stores, action: :read
      define :get_store, action: :read, get_by: [:id]
      define :create_store, action: :create
    end

    resource NepeanCircular.Flyers.Flyer do
      define :list_flyers, action: :read
      define :create_flyer, action: :create
      define :current_flyer_for_store, action: :current_for_store, args: [:store_id]
    end
  end
end

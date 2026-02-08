defmodule NepeanCircular.Flyers do
  use Ash.Domain

  resources do
    resource NepeanCircular.Flyers.Store do
      define(:list_stores, action: :read)
      define(:get_store, action: :read, get_by: [:id])
      define(:create_store, action: :create)
    end

    resource NepeanCircular.Flyers.Flyer do
      define(:list_flyers, action: :read)
      define(:create_flyer, action: :create)
      define(:current_flyer_for_store, action: :current_for_store, args: [:store_id])
    end

    resource NepeanCircular.Flyers.Subscriber do
      define(:subscribe, action: :subscribe)
      define(:unsubscribe, action: :unsubscribe)
      define(:list_active_subscribers, action: :active)
      define(:get_subscriber_by_token, action: :by_token, args: [:token])
    end
  end
end

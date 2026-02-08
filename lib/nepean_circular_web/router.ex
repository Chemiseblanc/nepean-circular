defmodule NepeanCircularWeb.Router do
  use NepeanCircularWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NepeanCircularWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check endpoint for K8s probes (no auth, no SSL redirect)
  scope "/" do
    get "/health", NepeanCircularWeb.HealthController, :index
  end

  scope "/", NepeanCircularWeb do
    pipe_through :browser

    live "/", HomeLive
    live "/stores/:id", StoreLive
    get "/flyers/combined.pdf", FlyerController, :combined
    get "/unsubscribe", UnsubscribeController, :unsubscribe
  end

  scope "/", NepeanCircularWeb do
    pipe_through :api

    post "/unsubscribe", UnsubscribeController, :unsubscribe
  end

  # Other scopes may use custom stacks.
  # scope "/api", NepeanCircularWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:nepean_circular, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: NepeanCircularWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

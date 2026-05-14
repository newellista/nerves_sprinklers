defmodule NervesSprinklersWeb.Router do
  use NervesSprinklersWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {NervesSprinklersWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Public routes — no auth required
  scope "/", NervesSprinklersWeb do
    pipe_through :browser

    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete

    live_session :public, layout: false do
      live "/setup", SetupLive, :index
    end
  end

  # Authenticated routes
  scope "/", NervesSprinklersWeb do
    pipe_through :browser

    live_session :authenticated,
      on_mount: [{NervesSprinklersWeb.Auth, :require_authenticated}] do
      live "/", DashboardLive, :index
      live "/settings", SettingsLive, :index
    end
  end
end

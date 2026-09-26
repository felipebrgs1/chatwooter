defmodule ChatwooterWeb.Router do
  use ChatwooterWeb, :router

  import ChatwooterWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ChatwooterWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ChatwooterWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", ChatwooterWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:chatwooter, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ChatwooterWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ChatwooterWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :dashboard,
      on_mount: [{ChatwooterWeb.UserAuth, :require_authenticated}],
      root_layout: {ChatwooterWeb.Layouts, :auth_root} do
      live "/app", DashboardLive, :index
      live "/app/settings", SettingsLive, :general
      live "/app/settings/inboxes", SettingsLive, :inboxes
      live "/app/settings/agents", SettingsLive, :agents
      live "/app/settings/profile", SettingsLive, :profile
      live "/app/settings/profile/confirm-email/:token", SettingsLive, :confirm_email
    end

    post "/app/update-password", UserSessionController, :update_password
  end

  scope "/", ChatwooterWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{ChatwooterWeb.UserAuth, :mount_current_scope}],
      root_layout: {ChatwooterWeb.Layouts, :auth_root} do
      live "/app/login", UserLive.Login, :new
      live "/app/login/:token", UserLive.Confirmation, :new
    end

    post "/app/login", UserSessionController, :create
    delete "/app/logout", UserSessionController, :delete
  end
end

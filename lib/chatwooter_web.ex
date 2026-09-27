defmodule ChatwooterWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use ChatwooterWeb, :controller
      use ChatwooterWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]

      use Gettext, backend: ChatwooterWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  @doc """
  Componente base (`components/next/`): só Phoenix.Component + CoreComponents.
  Importa outros componentes base explicitamente, se precisar.
  """
  def base_component do
    quote do
      use Phoenix.Component
      use Gettext, backend: ChatwooterWeb.Gettext

      import ChatwooterWeb.CoreComponents

      alias Phoenix.LiveView.JS

      unquote(verified_routes())
    end
  end

  @doc """
  Componente de tela (`components/<área>/`): base + todos os componentes `next/`.
  Componentes da mesma área são importados explicitamente.
  """
  def component do
    quote do
      unquote(base_component())
      use ChatwooterWeb.Components, :next
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: ChatwooterWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components + todos os componentes do app (lib/chatwooter_web/components.ex)
      import ChatwooterWeb.CoreComponents
      use ChatwooterWeb.Components

      # Common modules used in templates
      alias ChatwooterWeb.Layouts
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: ChatwooterWeb.Endpoint,
        router: ChatwooterWeb.Router,
        statics: ChatwooterWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end

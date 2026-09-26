defmodule ChatwooterWeb.PageController do
  use ChatwooterWeb, :controller

  def home(conn, _params) do
    if conn.assigns.current_scope do
      redirect(conn, to: ~p"/app")
    else
      redirect(conn, to: ~p"/users/log-in")
    end
  end
end

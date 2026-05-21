defmodule NervesSprinklersWeb.SessionController do
  @moduledoc false

  use NervesSprinklersWeb, :controller

  def new(conn, _params) do
    if NervesSprinklers.Auth.password_set?() do
      render(conn, :new)
    else
      redirect(conn, to: "/setup")
    end
  end

  def create(conn, %{"password" => password}) do
    if NervesSprinklers.Auth.verify_password(password) do
      conn
      |> put_session(:authenticated, true)
      |> redirect(to: "/")
    else
      conn
      |> put_flash(:error, "Incorrect password.")
      |> render(:new)
    end
  end

  def delete(conn, _params) do
    conn
    |> delete_session(:authenticated)
    |> redirect(to: "/login")
  end
end

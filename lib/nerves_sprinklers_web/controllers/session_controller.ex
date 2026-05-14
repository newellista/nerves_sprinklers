defmodule NervesSprinklersWeb.SessionController do
  use NervesSprinklersWeb, :controller

  def new(conn, _params) do
    if not NervesSprinklers.Auth.password_set?() do
      redirect(conn, to: "/setup")
    else
      render(conn, :new)
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

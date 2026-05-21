defmodule NervesSprinklersWeb.Auth do
  @moduledoc false

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(:require_authenticated, _params, session, socket) do
    socket = assign_auth(socket, session)

    cond do
      not socket.assigns.password_set? ->
        {:halt, push_navigate(socket, to: "/setup")}

      not socket.assigns.authenticated? ->
        {:halt, push_navigate(socket, to: "/login")}

      true ->
        {:cont, socket}
    end
  end

  defp assign_auth(socket, session) do
    socket
    |> assign(:password_set?, NervesSprinklers.Auth.password_set?())
    |> assign(:authenticated?, Map.get(session, "authenticated") == true)
  end
end

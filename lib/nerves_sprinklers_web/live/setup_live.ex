defmodule NervesSprinklersWeb.SetupLive do
  use NervesSprinklersWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if NervesSprinklers.Auth.password_set?() do
      {:ok, push_navigate(socket, to: "/login")}
    else
      {:ok,
       assign(socket,
         form: to_form(%{"password" => "", "password_confirmation" => ""}),
         error: nil
       )}
    end
  end

  @impl true
  def handle_event("save", %{"password" => pw, "password_confirmation" => confirm}, socket) do
    cond do
      byte_size(pw) < 8 ->
        {:noreply, assign(socket, error: "Password must be at least 8 characters.")}

      pw != confirm ->
        {:noreply, assign(socket, error: "Passwords do not match.")}

      true ->
        :ok = NervesSprinklers.Auth.set_password(pw)
        {:noreply, push_navigate(socket, to: "/login")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-gray-50">
      <div class="w-full max-w-md">
        <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
          <h1 class="text-2xl font-semibold text-gray-900 mb-2">Welcome to Sprinklers</h1>
          <p class="text-gray-500 text-sm mb-6">Create a password to secure your controller.</p>

          <.form for={@form} phx-submit="save" class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Password</label>
              <input
                type="password"
                name="password"
                required
                minlength="8"
                class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Confirm Password</label>
              <input
                type="password"
                name="password_confirmation"
                required
                class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
              />
            </div>
            <%= if @error do %>
              <p class="text-red-600 text-sm">{@error}</p>
            <% end %>
            <button
              type="submit"
              class="w-full bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-lg text-sm transition-colors"
            >
              Set Password
            </button>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end

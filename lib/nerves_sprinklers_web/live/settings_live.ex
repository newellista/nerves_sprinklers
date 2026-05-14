defmodule NervesSprinklersWeb.SettingsLive do
  use NervesSprinklersWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, error: nil, success: false)}
  end

  @impl true
  def handle_event("change_password", %{"current" => current, "password" => new_pw, "password_confirmation" => confirm}, socket) do
    cond do
      not NervesSprinklers.Auth.verify_password(current) ->
        {:noreply, assign(socket, error: "Current password is incorrect.", success: false)}

      byte_size(new_pw) < 8 ->
        {:noreply, assign(socket, error: "New password must be at least 8 characters.", success: false)}

      new_pw != confirm ->
        {:noreply, assign(socket, error: "Passwords do not match.", success: false)}

      true ->
        :ok = NervesSprinklers.Auth.set_password(new_pw)
        {:noreply, assign(socket, error: nil, success: true)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-lg">
      <h1 class="text-2xl font-semibold text-gray-900 mb-6">Settings</h1>

      <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
        <h2 class="text-base font-medium text-gray-900 mb-4">Change Password</h2>

        <.form for={%{}} phx-submit="change_password" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Current Password</label>
            <input type="password" name="current" required
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">New Password</label>
            <input type="password" name="password" required minlength="8"
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Confirm New Password</label>
            <input type="password" name="password_confirmation" required
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500" />
          </div>
          <%= if @error do %>
            <p class="text-red-600 text-sm">{@error}</p>
          <% end %>
          <%= if @success do %>
            <p class="text-green-600 text-sm">Password updated successfully.</p>
          <% end %>
          <button type="submit"
            class="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-lg text-sm transition-colors">
            Update Password
          </button>
        </.form>
      </div>
    </div>
    """
  end
end

defmodule NervesSprinklersWeb.DashboardLive do
  use NervesSprinklersWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, zones: [], active_zone: nil, connected_nodes: connected_nodes())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-semibold text-gray-900">Dashboard</h1>
        <div class="flex items-center gap-2 text-sm text-gray-500">
          <span class="inline-block w-2 h-2 rounded-full bg-green-400"></span>
          {length(@connected_nodes) + 1} node(s) online
        </div>
      </div>

      <%= if @zones == [] do %>
        <div class="rounded-2xl border border-dashed border-gray-300 p-12 text-center">
          <p class="text-gray-500 text-sm">No zones configured yet.</p>
          <p class="text-gray-400 text-xs mt-1">Zones will be configured in the next step.</p>
        </div>
      <% else %>
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
          <%= for zone <- @zones do %>
            <div class="bg-white rounded-xl border border-gray-200 p-4">
              <p class="font-medium text-gray-900 text-sm">{zone.name}</p>
              <p class="text-xs text-gray-400 mt-1">Zone {zone.number}</p>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp connected_nodes do
    Node.list()
  end
end

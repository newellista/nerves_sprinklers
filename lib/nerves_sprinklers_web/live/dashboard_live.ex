defmodule NervesSprinklersWeb.DashboardLive do
  use NervesSprinklersWeb, :live_view

  alias NervesSprinklers.Zones

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:zones, Zones.list_zones())
     |> assign(:active_zone, nil)
     |> assign(:active_run, nil)
     |> assign(:connected_nodes, Node.list())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">Dashboard</h1>
        <span class="text-sm text-gray-500">
          <%= length(@connected_nodes) + 1 %> node(s) connected
        </span>
      </div>

      <section class="mb-8">
        <h2 class="text-lg font-semibold mb-3">Zones</h2>
        <%= if @zones == [] do %>
          <p class="text-gray-500">No zones configured.</p>
        <% else %>
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            <%= for zone <- @zones do %>
              <div class="border rounded-lg p-4 bg-white shadow-sm">
                <div class="font-medium"><%= zone.name %></div>
                <div class="text-sm text-gray-500">Zone <%= zone.number %></div>
                <div class="text-xs text-gray-400 truncate"><%= zone.node %></div>
                <button
                  class="mt-2 w-full text-sm py-1 px-2 rounded bg-gray-100 text-gray-400 cursor-not-allowed"
                  disabled
                  title="Manual runs available after Phase 2"
                >
                  Run
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      </section>

      <section>
        <h2 class="text-lg font-semibold mb-3">Upcoming Runs</h2>
        <p class="text-gray-500">No schedules configured.</p>
      </section>
    </div>
    """
  end
end

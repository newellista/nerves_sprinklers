defmodule NervesSprinklersWeb.DashboardLive do
  use NervesSprinklersWeb, :live_view

  alias NervesSprinklers.Cluster.NodeWatcher
  alias NervesSprinklers.Config.NodeConfig
  alias NervesSprinklers.Executor.Executor
  alias NervesSprinklers.Scheduler.Recurrence
  alias NervesSprinklers.Schedules
  alias NervesSprinklers.Zones

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(NervesSprinklers.PubSub, "executor:status")
      Phoenix.PubSub.subscribe(NervesSprinklers.PubSub, "cluster:nodes")
    end

    {:ok,
     socket
     |> assign(:zones, Zones.list_zones())
     |> assign(:active_zone, nil)
     |> assign(:active_run, nil)
     |> assign(:connected_nodes, node_list())
     |> assign(:upcoming, compute_upcoming())}
  end

  @impl true
  def handle_info({:zone_activated, zone}, socket) do
    {:noreply, assign(socket, :active_zone, zone)}
  end

  def handle_info({:zone_completed, _zone}, socket) do
    {:noreply, assign(socket, :active_zone, nil)}
  end

  def handle_info({:run_completed, run_id}, socket) do
    {:noreply,
     socket
     |> assign(:active_zone, nil)
     |> assign(:active_run, run_id)
     |> assign(:upcoming, compute_upcoming())}
  end

  def handle_info({:run_aborted, _run_id}, socket) do
    {:noreply,
     socket
     |> assign(:active_zone, nil)
     |> assign(:active_run, nil)}
  end

  def handle_info({:node_up, node}, socket) do
    {:noreply, assign(socket, :connected_nodes, [node | socket.assigns.connected_nodes])}
  end

  def handle_info({:node_down, node}, socket) do
    nodes = Enum.reject(socket.assigns.connected_nodes, &(&1 == node))
    {:noreply, assign(socket, :connected_nodes, nodes)}
  end

  @impl true
  def handle_event("run_zone", %{"id" => id}, socket) do
    zone = Enum.find(socket.assigns.zones, &(&1.id == String.to_integer(id)))

    if zone do
      pseudo_schedule = %{
        id: nil,
        name: zone.name,
        seasonal_offset: 100,
        schedule_zones: [%{position: 1, duration_sec: 600, zone: zone}]
      }

      case Executor.start_run(pseudo_schedule, :manual) do
        :ok -> {:noreply, assign(socket, :active_run, :pending)}
        {:error, :busy} -> {:noreply, put_flash(socket, :error, "A run is already in progress.")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("abort_run", _params, socket) do
    Executor.abort_run()
    {:noreply, socket}
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

      <%= if @active_run do %>
        <div class="mb-4 flex items-center gap-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
          <span class="text-sm text-blue-700 font-medium">Run in progress</span>
          <button
            phx-click="abort_run"
            class="text-sm px-3 py-1 bg-red-600 text-white rounded hover:bg-red-700"
          >
            Abort
          </button>
        </div>
      <% end %>

      <section class="mb-8">
        <h2 class="text-lg font-semibold mb-3">Zones</h2>
        <%= if @zones == [] do %>
          <p class="text-gray-500">
            No zones configured. <.link navigate={~p"/zones"}>Add zones</.link>
          </p>
        <% else %>
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            <%= for zone <- @zones do %>
              <div class={[
                "border rounded-lg p-4 bg-white shadow-sm transition-colors",
                @active_zone && @active_zone.id == zone.id && "border-blue-400 bg-blue-50"
              ]}>
                <div class="font-medium"><%= zone.name %></div>
                <div class="text-sm text-gray-500">Zone <%= zone.number %></div>
                <div class="text-xs text-gray-400 truncate"><%= zone.node %></div>
                <%= if @active_zone && @active_zone.id == zone.id do %>
                  <div class="mt-2 text-xs text-blue-600 font-medium animate-pulse">Running…</div>
                <% else %>
                  <button
                    phx-click="run_zone"
                    phx-value-id={zone.id}
                    disabled={@active_run != nil}
                    class="mt-2 w-full text-sm py-1 px-2 rounded bg-green-600 text-white hover:bg-green-700 disabled:bg-gray-100 disabled:text-gray-400 disabled:cursor-not-allowed"
                  >
                    Run
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </section>

      <section>
        <h2 class="text-lg font-semibold mb-3">Upcoming Runs</h2>
        <%= if @upcoming == [] do %>
          <p class="text-gray-500">
            No scheduled runs. <.link navigate={~p"/schedules"}>Configure schedules</.link>
          </p>
        <% else %>
          <div class="space-y-2">
            <%= for {schedule, next_dt} <- @upcoming do %>
              <div class="flex items-center justify-between p-3 bg-white border rounded-lg shadow-sm">
                <span class="font-medium text-sm"><%= schedule.name %></span>
                <span class="text-sm text-gray-500">
                  <%= format_dt(next_dt) %>
                </span>
              </div>
            <% end %>
          </div>
        <% end %>
      </section>
    </div>
    """
  end

  defp node_list do
    if Process.whereis(NodeWatcher) do
      NodeWatcher.connected_nodes()
    else
      [node() | Node.list()]
    end
  end

  defp compute_upcoming do
    timezone = NodeConfig.timezone()
    now = DateTime.utc_now()

    Schedules.list_schedules()
    |> Enum.filter(& &1.enabled)
    |> Enum.flat_map(fn schedule ->
      case Recurrence.next_run_after(schedule, now, timezone) do
        nil -> []
        dt -> [{schedule, dt}]
      end
    end)
    |> Enum.sort_by(fn {_s, dt} -> dt end, DateTime)
    |> Enum.take(5)
  end

  defp format_dt(dt) do
    Calendar.strftime(DateTime.to_naive(dt), "%a %b %-d at %-I:%M %p")
  end
end

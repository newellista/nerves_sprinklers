defmodule NervesSprinklersWeb.HistoryLive do
  use NervesSprinklersWeb, :live_view

  alias NervesSprinklers.History

  @per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page, 1)
     |> assign(:total, History.count_schedule_runs())
     |> assign(:runs, History.list_schedule_runs(limit: @per_page, offset: 0))}
  end

  @impl true
  def handle_event("prev_page", _params, socket) do
    page = max(1, socket.assigns.page - 1)
    {:noreply, load_page(socket, page)}
  end

  def handle_event("next_page", _params, socket) do
    max_page = ceil_div(socket.assigns.total, @per_page)
    page = min(max_page, socket.assigns.page + 1)
    {:noreply, load_page(socket, page)}
  end

  def handle_event("toggle_details", %{"id" => id}, socket) do
    id = String.to_integer(id)
    expanded = socket.assigns[:expanded] || MapSet.new()

    expanded =
      if MapSet.member?(expanded, id),
        do: MapSet.delete(expanded, id),
        else: MapSet.put(expanded, id)

    {:noreply, assign(socket, :expanded, expanded)}
  end

  @impl true
  def render(assigns) do
    assigns = assign_new(assigns, :expanded, fn -> MapSet.new() end)

    ~H"""
    <div class="p-6">
      <h1 class="text-2xl font-bold mb-6">Run History</h1>

      <%= if @runs == [] do %>
        <p class="text-gray-500">No runs recorded yet.</p>
      <% else %>
        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200 text-sm">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-4 py-2 text-left font-medium text-gray-500">Schedule</th>
                <th class="px-4 py-2 text-left font-medium text-gray-500">Trigger</th>
                <th class="px-4 py-2 text-left font-medium text-gray-500">Started</th>
                <th class="px-4 py-2 text-left font-medium text-gray-500">Duration</th>
                <th class="px-4 py-2 text-left font-medium text-gray-500">Status</th>
                <th class="px-4 py-2"></th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-100">
              <%= for run <- @runs do %>
                <tr class="hover:bg-gray-50">
                  <td class="px-4 py-2 font-medium"><%= run.schedule_name %></td>
                  <td class="px-4 py-2 capitalize text-gray-500"><%= run.trigger_type %></td>
                  <td class="px-4 py-2 text-gray-500 whitespace-nowrap">
                    <%= format_dt(run.started_at) %>
                  </td>
                  <td class="px-4 py-2 text-gray-500 whitespace-nowrap">
                    <%= format_duration(run.started_at, run.completed_at) %>
                  </td>
                  <td class="px-4 py-2">
                    <span class={status_class(run.status)}>
                      <%= run.status %>
                    </span>
                  </td>
                  <td class="px-4 py-2">
                    <%= if run.zone_runs != [] do %>
                      <button
                        phx-click="toggle_details"
                        phx-value-id={run.id}
                        class="text-xs text-blue-600 hover:underline"
                      >
                        <%= if MapSet.member?(@expanded, run.id), do: "Hide", else: "Details" %>
                      </button>
                    <% end %>
                  </td>
                </tr>
                <%= if MapSet.member?(@expanded, run.id) do %>
                  <tr>
                    <td colspan="6" class="px-4 pb-3 bg-gray-50">
                      <table class="w-full text-xs text-gray-600">
                        <thead>
                          <tr>
                            <th class="text-left py-1">Zone</th>
                            <th class="text-left py-1">Planned</th>
                            <th class="text-left py-1">Actual</th>
                            <th class="text-left py-1">Status</th>
                          </tr>
                        </thead>
                        <tbody>
                          <%= for zr <- run.zone_runs do %>
                            <tr>
                              <td class="py-0.5"><%= zr.zone_name %> (#<%= zr.zone_number %>)</td>
                              <td class="py-0.5"><%= format_sec(zr.planned_duration_sec) %></td>
                              <td class="py-0.5"><%= format_sec(zr.actual_duration_sec) %></td>
                              <td class="py-0.5 capitalize"><%= zr.status %></td>
                            </tr>
                          <% end %>
                        </tbody>
                      </table>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>

        <div class="flex items-center justify-between mt-4 text-sm text-gray-500">
          <span>
            Page <%= @page %> of <%= ceil_div(@total, @per_page) %>
            (<%= @total %> total)
          </span>
          <div class="flex gap-2">
            <button
              phx-click="prev_page"
              disabled={@page == 1}
              class="px-3 py-1 rounded border disabled:opacity-40 hover:bg-gray-50"
            >
              Prev
            </button>
            <button
              phx-click="next_page"
              disabled={@page >= ceil_div(@total, @per_page)}
              class="px-3 py-1 rounded border disabled:opacity-40 hover:bg-gray-50"
            >
              Next
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp load_page(socket, page) do
    offset = (page - 1) * @per_page

    socket
    |> assign(:page, page)
    |> assign(:total, History.count_schedule_runs())
    |> assign(:runs, History.list_schedule_runs(limit: @per_page, offset: offset))
  end

  defp format_dt(nil), do: "—"

  defp format_dt(dt) do
    Calendar.strftime(DateTime.to_naive(dt), "%Y-%m-%d %H:%M")
  end

  defp format_duration(_, nil), do: "—"

  defp format_duration(nil, _), do: "—"

  defp format_duration(started, completed) do
    seconds = DateTime.diff(completed, started)
    format_sec(seconds)
  end

  defp format_sec(nil), do: "—"

  defp format_sec(sec) when sec < 60, do: "#{sec}s"

  defp format_sec(sec) do
    "#{div(sec, 60)}m #{rem(sec, 60)}s"
  end

  defp status_class(:completed),
    do: "inline-block px-2 py-0.5 rounded text-xs bg-green-100 text-green-700"

  defp status_class(:running),
    do: "inline-block px-2 py-0.5 rounded text-xs bg-blue-100 text-blue-700"

  defp status_class(:aborted),
    do: "inline-block px-2 py-0.5 rounded text-xs bg-yellow-100 text-yellow-700"

  defp status_class(_), do: "inline-block px-2 py-0.5 rounded text-xs bg-red-100 text-red-700"

  defp ceil_div(_, 0), do: 1
  defp ceil_div(a, b), do: div(a + b - 1, b)
end

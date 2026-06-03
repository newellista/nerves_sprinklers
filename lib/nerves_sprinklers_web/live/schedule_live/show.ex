defmodule NervesSprinklersWeb.ScheduleLive.Show do
  use NervesSprinklersWeb, :live_view

  alias NervesSprinklers.Config.NodeConfig
  alias NervesSprinklers.Executor.Executor
  alias NervesSprinklers.History
  alias NervesSprinklers.Scheduler.Recurrence
  alias NervesSprinklers.Schedules

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    schedule = Schedules.get_schedule!(id)
    timezone = NodeConfig.timezone()
    next_run = Recurrence.next_run_after(schedule, DateTime.utc_now(), timezone)
    recent_runs = History.list_schedule_runs(limit: 5)

    {:noreply,
     socket
     |> assign(:schedule, schedule)
     |> assign(:timezone, timezone)
     |> assign(:next_run, next_run)
     |> assign(:recent_runs, recent_runs)}
  end

  @impl true
  def handle_event("run_now", _params, socket) do
    schedule = socket.assigns.schedule

    case Executor.start_run(schedule, :manual) do
      :ok ->
        {:noreply, put_flash(socket, :info, "Started run for \"#{schedule.name}\".")}

      {:error, :busy} ->
        {:noreply, put_flash(socket, :error, "A run is already in progress.")}
    end
  end

  def handle_event("resume", _params, socket) do
    {:ok, schedule} = Schedules.resume_schedule(socket.assigns.schedule)
    timezone = NodeConfig.timezone()
    next_run = Recurrence.next_run_after(schedule, DateTime.utc_now(), timezone)
    {:noreply, socket |> assign(:schedule, schedule) |> assign(:next_run, next_run)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 max-w-2xl">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold"><%= @schedule.name %></h1>
        <div class="flex gap-2">
          <button
            phx-click="run_now"
            class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 text-sm"
          >
            Run Now
          </button>
          <.link
            navigate={~p"/schedules/#{@schedule.id}/edit"}
            class="px-4 py-2 border rounded text-sm hover:bg-gray-50"
          >
            Edit
          </.link>
          <.link navigate={~p"/schedules"} class="px-4 py-2 border rounded text-sm hover:bg-gray-50">
            Back
          </.link>
        </div>
      </div>

      <div class="bg-white border rounded-lg divide-y mb-6">
        <div class="px-4 py-3 flex justify-between text-sm">
          <span class="text-gray-500">Status</span>
          <span class={if @schedule.enabled, do: "text-green-600 font-medium", else: "text-gray-400"}>
            <%= if @schedule.enabled, do: "Enabled", else: "Disabled" %>
          </span>
        </div>

        <div class="px-4 py-3 flex justify-between text-sm">
          <span class="text-gray-500">Recurrence</span>
          <span><%= recurrence_label(@schedule) %></span>
        </div>

        <div class="px-4 py-3 flex justify-between text-sm">
          <span class="text-gray-500">Start time</span>
          <span><%= Calendar.strftime(@schedule.start_time, "%-I:%M %p") %></span>
        </div>

        <div class="px-4 py-3 flex justify-between text-sm">
          <span class="text-gray-500">Seasonal offset</span>
          <span><%= @schedule.seasonal_offset %>%</span>
        </div>

        <div class="px-4 py-3 flex justify-between text-sm">
          <span class="text-gray-500">Next run</span>
          <span>
            <%= if @next_run, do: format_dt(@next_run), else: "—" %>
          </span>
        </div>

        <%= if @schedule.paused_until do %>
          <div class="px-4 py-3 flex justify-between items-center text-sm">
            <span class="text-gray-500">
              Paused until <%= Calendar.strftime(@schedule.paused_until, "%b %-d, %Y") %>
            </span>
            <button
              phx-click="resume"
              class="text-blue-600 hover:text-blue-800 font-medium"
            >
              Resume
            </button>
          </div>
        <% end %>
      </div>

      <%= if @schedule.schedule_zones != [] do %>
        <div class="mb-6">
          <h2 class="text-lg font-semibold mb-3">Zone Order</h2>
          <div class="bg-white border rounded-lg divide-y">
            <%= for {sz, i} <- Enum.with_index(@schedule.schedule_zones, 1) do %>
              <div class="px-4 py-3 flex justify-between items-center text-sm">
                <span class="text-gray-400 w-6"><%= i %>.</span>
                <span class="flex-1 font-medium"><%= sz.zone.name %></span>
                <span class="text-gray-500">
                  <%= format_sec(floor(sz.duration_sec * @schedule.seasonal_offset / 100)) %>
                </span>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @recent_runs != [] do %>
        <div>
          <h2 class="text-lg font-semibold mb-3">Recent Runs</h2>
          <div class="bg-white border rounded-lg divide-y">
            <%= for run <- @recent_runs do %>
              <div class="px-4 py-3 flex justify-between items-center text-sm">
                <span class="text-gray-500"><%= format_dt(run.started_at) %></span>
                <span class={status_class(run.status)}><%= run.status %></span>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp recurrence_label(%{recurrence_type: :every_n_days, recurrence_days: n}) when n == 1,
    do: "Every day"

  defp recurrence_label(%{recurrence_type: :every_n_days, recurrence_days: n}),
    do: "Every #{n} days"

  defp recurrence_label(%{recurrence_type: :days_of_week, recurrence_dow: dow}) do
    days = %{1 => "Mon", 2 => "Tue", 3 => "Wed", 4 => "Thu", 5 => "Fri", 6 => "Sat", 7 => "Sun"}
    dow |> Enum.sort() |> Enum.map_join(", ", &days[&1])
  end

  defp format_dt(nil), do: "—"

  defp format_dt(%DateTime{} = dt) do
    Calendar.strftime(DateTime.to_naive(dt), "%a %b %-d at %-I:%M %p")
  end

  defp format_dt(%NaiveDateTime{} = ndt) do
    Calendar.strftime(ndt, "%a %b %-d at %-I:%M %p")
  end

  defp format_sec(sec) when sec < 60, do: "#{sec}s"
  defp format_sec(sec), do: "#{div(sec, 60)}m #{rem(sec, 60)}s"

  defp status_class(:completed),
    do: "inline-block px-2 py-0.5 rounded text-xs bg-green-100 text-green-700"

  defp status_class(:running),
    do: "inline-block px-2 py-0.5 rounded text-xs bg-blue-100 text-blue-700"

  defp status_class(:aborted),
    do: "inline-block px-2 py-0.5 rounded text-xs bg-yellow-100 text-yellow-700"

  defp status_class(_), do: "inline-block px-2 py-0.5 rounded text-xs bg-red-100 text-red-700"
end

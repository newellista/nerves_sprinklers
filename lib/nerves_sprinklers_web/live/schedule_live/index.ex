defmodule NervesSprinklersWeb.ScheduleLive.Index do
  @moduledoc false

  use NervesSprinklersWeb, :live_view

  alias NervesSprinklers.Config.NodeConfig
  alias NervesSprinklers.Executor.Executor
  alias NervesSprinklers.Scheduler.ConflictChecker
  alias NervesSprinklers.{Schedules, Zones}
  alias NervesSprinklers.Schema.Schedule

  @dow_labels %{
    1 => "Mon",
    2 => "Tue",
    3 => "Wed",
    4 => "Thu",
    5 => "Fri",
    6 => "Sat",
    7 => "Sun"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:schedules, Schedules.list_schedules())
     |> assign(:zones, Zones.list_zones())
     |> assign(:schedule, nil)
     |> assign(:changeset, nil)
     |> assign(:conflict, nil)
     |> assign(:pending_save, nil)
     |> assign(:zone_assignments, [])
     |> assign(:timezone, NodeConfig.timezone())}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    schedule = Schedules.get_schedule!(id)

    zone_assignments =
      schedule
      |> Schedules.list_schedule_zones()
      |> Enum.map(&%{zone_id: &1.zone_id, duration_sec: &1.duration_sec})

    {:noreply,
     socket
     |> assign(:schedule, schedule)
     |> assign(:changeset, Schedules.change_schedule(schedule))
     |> assign(:zone_assignments, zone_assignments)
     |> assign(:conflict, nil)
     |> assign(:pending_save, nil)}
  end

  def handle_params(_params, _uri, socket) do
    case socket.assigns.live_action do
      :new ->
        {:noreply,
         socket
         |> assign(:schedule, %Schedule{})
         |> assign(:changeset, Schedules.change_schedule(%Schedule{}))
         |> assign(:zone_assignments, [])
         |> assign(:conflict, nil)
         |> assign(:pending_save, nil)}

      _ ->
        {:noreply,
         socket
         |> assign(:schedule, nil)
         |> assign(:changeset, nil)
         |> assign(:zone_assignments, [])
         |> assign(:conflict, nil)
         |> assign(:pending_save, nil)}
    end
  end

  @impl true
  def handle_event("validate", %{"schedule" => params}, socket) do
    changeset =
      (socket.assigns.schedule || %Schedule{})
      |> Schedules.change_schedule(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"schedule" => params}, socket) do
    candidate = build_candidate(socket, params)

    case ConflictChecker.check(candidate, Schedules.list_schedules()) do
      {:conflict, details} ->
        {:noreply,
         socket
         |> assign(:conflict, details)
         |> assign(:pending_save, params)}

      :ok ->
        do_save(socket, socket.assigns.live_action, params)
    end
  end

  def handle_event("save_anyway", _params, socket) do
    do_save(socket, socket.assigns.live_action, socket.assigns.pending_save)
  end

  def handle_event("cancel_conflict", _params, socket) do
    {:noreply,
     socket
     |> assign(:conflict, nil)
     |> assign(:pending_save, nil)}
  end

  def handle_event("toggle_enabled", %{"id" => id}, socket) do
    schedule = Schedules.get_schedule!(id)
    {:ok, _} = Schedules.set_enabled(schedule, !schedule.enabled)
    {:noreply, assign(socket, :schedules, Schedules.list_schedules())}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    schedule = Schedules.get_schedule!(id)
    {:ok, _} = Schedules.delete_schedule(schedule)
    {:noreply, assign(socket, :schedules, Schedules.list_schedules())}
  end

  def handle_event("run_schedule", %{"id" => id}, socket) do
    schedule = Schedules.get_schedule!(String.to_integer(id))

    case Executor.start_run(schedule, :manual) do
      :ok ->
        {:noreply, put_flash(socket, :info, "Started run for \"#{schedule.name}\".")}

      {:error, :busy} ->
        {:noreply, put_flash(socket, :error, "A run is already in progress.")}
    end
  end

  def handle_event("add_zone", %{"zone_id" => zone_id}, socket) do
    zone_id_int = String.to_integer(zone_id)
    already_added = Enum.any?(socket.assigns.zone_assignments, &(&1.zone_id == zone_id_int))

    if already_added do
      {:noreply, socket}
    else
      assignment = %{zone_id: zone_id_int, duration_sec: 600}

      {:noreply,
       assign(socket, :zone_assignments, socket.assigns.zone_assignments ++ [assignment])}
    end
  end

  def handle_event("remove_zone", %{"zone_id" => zone_id}, socket) do
    zone_id_int = String.to_integer(zone_id)
    updated = Enum.reject(socket.assigns.zone_assignments, &(&1.zone_id == zone_id_int))
    {:noreply, assign(socket, :zone_assignments, updated)}
  end

  def handle_event("update_duration", %{"zone_id" => zone_id, "duration" => duration}, socket) do
    zone_id_int = String.to_integer(zone_id)
    duration_int = String.to_integer(duration)

    updated =
      Enum.map(
        socket.assigns.zone_assignments,
        fn
          %{zone_id: ^zone_id_int} = a -> %{a | duration_sec: duration_int}
          a -> a
        end
      )

    {:noreply, assign(socket, :zone_assignments, updated)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <%= if @live_action in [:new, :edit] do %>
        <.schedule_form
          changeset={@changeset}
          live_action={@live_action}
          zones={@zones}
          zone_assignments={@zone_assignments}
          conflict={@conflict}
          timezone={@timezone}
        />
      <% else %>
        <.schedule_index schedules={@schedules} />
      <% end %>
    </div>
    """
  end

  defp schedule_index(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-2xl font-bold">Schedules</h1>
      <.link
        navigate={~p"/schedules/new"}
        class="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-lg text-sm transition-colors"
      >
        New schedule
      </.link>
    </div>

    <div class="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Name
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Recurrence
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Start Time
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Enabled
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Next Run
            </th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Actions
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <%= for schedule <- @schedules do %>
            <tr>
              <td class="px-4 py-3 text-sm text-gray-900"><%= schedule.name %></td>
              <td class="px-4 py-3 text-sm text-gray-500">
                <%= recurrence_description(schedule) %>
              </td>
              <td class="px-4 py-3 text-sm text-gray-500">
                <%= format_time(schedule.start_time) %>
              </td>
              <td class="px-4 py-3 text-sm">
                <button
                  phx-click="toggle_enabled"
                  phx-value-id={schedule.id}
                  class={if schedule.enabled, do: "text-green-600 hover:text-green-800 font-medium", else: "text-gray-400 hover:text-gray-600 font-medium"}
                >
                  <%= if schedule.enabled, do: "Enabled", else: "Disabled" %>
                </button>
              </td>
              <td class="px-4 py-3 text-sm text-gray-400">—</td>
              <td class="px-4 py-3 text-sm space-x-2">
                <.link
                  navigate={~p"/schedules/#{schedule.id}"}
                  class="text-gray-600 hover:text-gray-800 font-medium"
                >
                  View
                </.link>
                <.link
                  navigate={~p"/schedules/#{schedule.id}/edit"}
                  class="text-blue-600 hover:text-blue-800 font-medium"
                >
                  Edit
                </.link>
                <button
                  phx-click="run_schedule"
                  phx-value-id={schedule.id}
                  class="text-green-600 hover:text-green-800 font-medium"
                >
                  Run
                </button>
                <button
                  phx-click="delete"
                  phx-value-id={schedule.id}
                  phx-confirm={"Delete schedule \"#{schedule.name}\"?"}
                  class="text-red-600 hover:text-red-800 font-medium"
                >
                  Delete
                </button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp schedule_form(assigns) do
    ~H"""
    <div class="max-w-xl">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">
          <%= if @live_action == :new, do: "New Schedule", else: "Edit Schedule" %>
        </h1>
        <.link navigate={~p"/schedules"} class="text-gray-500 hover:text-gray-700 text-sm">
          Cancel
        </.link>
      </div>

      <%= if @conflict do %>
        <div class="bg-yellow-50 border border-yellow-300 rounded-lg p-4 mb-6">
          <p class="text-yellow-800 text-sm">
            ⚠ This schedule overlaps with <strong><%= @conflict.schedule.name %></strong>
            on <%= Date.to_iso8601(@conflict.day) %> (<%= @conflict.overlap_minutes %> min overlap).
          </p>
          <div class="flex gap-2 mt-3">
            <button
              phx-click="save_anyway"
              class="bg-yellow-600 hover:bg-yellow-700 text-white font-medium py-1 px-3 rounded text-sm transition-colors"
            >
              Save anyway
            </button>
            <button
              phx-click="cancel_conflict"
              class="bg-white hover:bg-gray-50 border border-gray-300 text-gray-700 font-medium py-1 px-3 rounded text-sm transition-colors"
            >
              Cancel
            </button>
          </div>
        </div>
      <% end %>

      <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
        <.form for={@changeset} phx-change="validate" phx-submit="save" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
            <input
              type="text"
              name="schedule[name]"
              value={Ecto.Changeset.get_field(@changeset, :name)}
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
            />
            <%= for error <- Keyword.get_values(@changeset.errors, :name) do %>
              <p class="text-red-600 text-xs mt-1"><%= translate_error(error) %></p>
            <% end %>
          </div>

          <div class="flex items-center gap-2">
            <input
              type="checkbox"
              name="schedule[enabled]"
              id="schedule_enabled"
              value="true"
              checked={Ecto.Changeset.get_field(@changeset, :enabled) != false}
              class="rounded border-gray-300 text-green-600 focus:ring-green-500"
            />
            <label for="schedule_enabled" class="text-sm font-medium text-gray-700">Enabled</label>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Recurrence</label>
            <div class="space-y-1">
              <label class="flex items-center gap-2 text-sm text-gray-700">
                <input
                  type="radio"
                  name="schedule[recurrence_type]"
                  value="every_n_days"
                  checked={Ecto.Changeset.get_field(@changeset, :recurrence_type) == :every_n_days}
                  class="border-gray-300 text-green-600 focus:ring-green-500"
                />
                Every N days
              </label>
              <label class="flex items-center gap-2 text-sm text-gray-700">
                <input
                  type="radio"
                  name="schedule[recurrence_type]"
                  value="days_of_week"
                  checked={Ecto.Changeset.get_field(@changeset, :recurrence_type) == :days_of_week}
                  class="border-gray-300 text-green-600 focus:ring-green-500"
                />
                Days of week
              </label>
            </div>
            <%= for error <- Keyword.get_values(@changeset.errors, :recurrence_type) do %>
              <p class="text-red-600 text-xs mt-1"><%= translate_error(error) %></p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Every N days</label>
            <input
              type="number"
              name="schedule[recurrence_days]"
              value={Ecto.Changeset.get_field(@changeset, :recurrence_days)}
              min="1"
              class="w-24 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
            />
            <%= for error <- Keyword.get_values(@changeset.errors, :recurrence_days) do %>
              <p class="text-red-600 text-xs mt-1"><%= translate_error(error) %></p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Days of week</label>
            <div class="flex flex-wrap gap-3">
              <%= for {day_int, label} <- [{1, "Mon"}, {2, "Tue"}, {3, "Wed"}, {4, "Thu"}, {5, "Fri"}, {6, "Sat"}, {7, "Sun"}] do %>
                <label class="flex items-center gap-1 text-sm text-gray-700">
                  <input
                    type="checkbox"
                    name="schedule[recurrence_dow][]"
                    value={day_int}
                    checked={day_int in (Ecto.Changeset.get_field(@changeset, :recurrence_dow) || [])}
                    class="rounded border-gray-300 text-green-600 focus:ring-green-500"
                  />
                  <%= label %>
                </label>
              <% end %>
            </div>
            <%= for error <- Keyword.get_values(@changeset.errors, :recurrence_dow) do %>
              <p class="text-red-600 text-xs mt-1"><%= translate_error(error) %></p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
            <input
              type="date"
              name="schedule[start_date]"
              value={Ecto.Changeset.get_field(@changeset, :start_date)}
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
            />
            <%= for error <- Keyword.get_values(@changeset.errors, :start_date) do %>
              <p class="text-red-600 text-xs mt-1"><%= translate_error(error) %></p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Start Time <span class="text-gray-400 font-normal">(Times are in <%= @timezone %>)</span>
            </label>
            <input
              type="time"
              name="schedule[start_time]"
              value={format_time(Ecto.Changeset.get_field(@changeset, :start_time))}
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
            />
            <%= for error <- Keyword.get_values(@changeset.errors, :start_time) do %>
              <p class="text-red-600 text-xs mt-1"><%= translate_error(error) %></p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              Seasonal adjustment (%)
            </label>
            <input
              type="number"
              name="schedule[seasonal_offset]"
              value={Ecto.Changeset.get_field(@changeset, :seasonal_offset) || 100}
              min="1"
              max="200"
              class="w-24 rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
            />
            <%= for error <- Keyword.get_values(@changeset.errors, :seasonal_offset) do %>
              <p class="text-red-600 text-xs mt-1"><%= translate_error(error) %></p>
            <% end %>
          </div>

          <div>
            <h3 class="text-sm font-medium text-gray-700 mb-3">Zone Assignments</h3>

            <%= if @zone_assignments != [] do %>
              <div class="space-y-2 mb-3">
                <%= for assignment <- @zone_assignments do %>
                  <% zone = Enum.find(@zones, &(&1.id == assignment.zone_id)) %>
                  <div class="flex items-center gap-3 bg-gray-50 rounded-lg p-2">
                    <span class="text-sm text-gray-800 flex-1">
                      <%= if zone, do: zone.name, else: "Zone #{assignment.zone_id}" %>
                    </span>
                    <input
                      type="number"
                      value={assignment.duration_sec}
                      min="1"
                      phx-blur="update_duration"
                      phx-value-zone_id={assignment.zone_id}
                      phx-value-duration={assignment.duration_sec}
                      class="w-24 rounded border border-gray-300 px-2 py-1 text-sm focus:outline-none focus:ring-1 focus:ring-green-500"
                    />
                    <span class="text-xs text-gray-500">sec</span>
                    <button
                      type="button"
                      phx-click="remove_zone"
                      phx-value-zone_id={assignment.zone_id}
                      class="text-red-500 hover:text-red-700 text-sm font-medium"
                    >
                      Remove
                    </button>
                  </div>
                <% end %>
              </div>
            <% end %>

            <% available_zones = Enum.reject(@zones, fn z -> Enum.any?(@zone_assignments, &(&1.zone_id == z.id)) end) %>
            <%= if available_zones != [] do %>
              <div class="flex gap-2">
                <select
                  id="zone_select"
                  class="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
                >
                  <%= for zone <- available_zones do %>
                    <option value={zone.id}><%= zone.name %></option>
                  <% end %>
                </select>
                <button
                  type="button"
                  phx-click="add_zone"
                  phx-value-zone_id={List.first(available_zones).id}
                  class="bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-2 px-3 rounded-lg text-sm transition-colors"
                >
                  Add
                </button>
              </div>
            <% end %>
          </div>

          <div class="flex gap-3 pt-2">
            <button
              type="submit"
              class="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-lg text-sm transition-colors"
            >
              Save schedule
            </button>
            <.link navigate={~p"/schedules"} class="text-gray-500 hover:text-gray-700 text-sm py-2">
              Cancel
            </.link>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  defp do_save(socket, live_action, params) do
    result =
      case live_action do
        :new -> Schedules.create_schedule(params)
        :edit -> Schedules.update_schedule(socket.assigns.schedule, params)
      end

    case result do
      {:ok, schedule} ->
        Schedules.set_schedule_zones(schedule, socket.assigns.zone_assignments)

        {:noreply,
         socket
         |> assign(:schedules, Schedules.list_schedules())
         |> assign(:conflict, nil)
         |> assign(:pending_save, nil)
         |> push_navigate(to: ~p"/schedules")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:changeset, changeset)
         |> assign(:conflict, nil)
         |> assign(:pending_save, nil)}
    end
  end

  defp build_candidate(socket, params) do
    base = socket.assigns.schedule || %Schedule{}

    changeset = Schedules.change_schedule(base, params)
    candidate = Ecto.Changeset.apply_changes(changeset)

    zone_structs =
      Enum.with_index(socket.assigns.zone_assignments, 1)
      |> Enum.map(fn {%{zone_id: zone_id, duration_sec: duration_sec}, position} ->
        %NervesSprinklers.Schema.ScheduleZone{
          zone_id: zone_id,
          schedule_id: candidate.id,
          position: position,
          duration_sec: duration_sec
        }
      end)

    %{candidate | schedule_zones: zone_structs}
  end

  defp recurrence_description(%Schedule{recurrence_type: :every_n_days, recurrence_days: days}) do
    "Every #{days} #{if days == 1, do: "day", else: "days"}"
  end

  defp recurrence_description(%Schedule{recurrence_type: :days_of_week, recurrence_dow: dow})
       when is_list(dow) do
    dow
    |> Enum.sort()
    |> Enum.map_join("/", &Map.get(@dow_labels, &1, to_string(&1)))
  end

  defp recurrence_description(_), do: "—"

  defp format_time(nil), do: ""

  defp format_time(%Time{} = t) do
    t
    |> Time.to_string()
    |> String.slice(0, 5)
  end

  defp format_time(t) when is_binary(t), do: String.slice(t, 0, 5)

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end

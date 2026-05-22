defmodule NervesSprinklersWeb.ZonesLive do
  @moduledoc false

  use NervesSprinklersWeb, :live_view

  alias NervesSprinklers.Executor.ZoneDriver
  alias NervesSprinklers.Schema.Zone
  alias NervesSprinklers.Zones

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:zones, Zones.list_zones())
     |> assign(:zone_groups, Zones.list_zone_groups())
     |> assign(:changeset, nil)
     |> assign(:zone, nil)
     |> assign(:testing_zone_id, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    zone = Zones.get_zone!(id)

    {:noreply,
     socket
     |> assign(:live_action, :edit)
     |> assign(:zone, zone)
     |> assign(:changeset, Zones.change_zone(zone))}
  end

  def handle_params(_params, _uri, socket) do
    case socket.assigns.live_action do
      :new ->
        {:noreply,
         socket
         |> assign(:zone, nil)
         |> assign(:changeset, Zones.change_zone(%Zone{}))}

      _ ->
        {:noreply,
         socket
         |> assign(:zone, nil)
         |> assign(:changeset, nil)}
    end
  end

  @impl true
  def handle_event("validate", %{"zone" => params}, socket) do
    changeset =
      (socket.assigns.zone || %Zone{})
      |> Zones.change_zone(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save", %{"zone" => params}, socket) do
    result =
      case socket.assigns.live_action do
        :new -> Zones.create_zone(params)
        :edit -> Zones.update_zone(socket.assigns.zone, params)
      end

    case result do
      {:ok, _zone} ->
        {:noreply,
         socket
         |> assign(:zones, Zones.list_zones())
         |> push_navigate(to: ~p"/zones")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    zone = Enum.find(socket.assigns.zones, &(to_string(&1.id) == id))
    {:ok, _} = Zones.delete_zone(zone)
    {:noreply, assign(socket, :zones, Zones.list_zones())}
  end

  def handle_event("test_zone", %{"id" => id}, socket) do
    zone = Enum.find(socket.assigns.zones, &(to_string(&1.id) == id))

    case ZoneDriver.activate(zone) do
      {:error, :unreachable} ->
        {:noreply, put_flash(socket, :error, "Zone unreachable")}

      _ ->
        Process.send_after(self(), {:close_test_zone, String.to_integer(id)}, 2_000)
        {:noreply, assign(socket, :testing_zone_id, zone.id)}
    end
  end

  def handle_event("create_group", %{"name" => name}, socket) do
    {:ok, _} = Zones.create_zone_group(%{name: name})
    {:noreply, assign(socket, :zone_groups, Zones.list_zone_groups())}
  end

  def handle_event("delete_group", %{"id" => id}, socket) do
    group = Enum.find(socket.assigns.zone_groups, &(to_string(&1.id) == id))
    {:ok, _} = Zones.delete_zone_group(group)
    {:noreply, assign(socket, :zone_groups, Zones.list_zone_groups())}
  end

  def handle_event("add_zone_to_group", %{"zone_id" => z_id, "group_id" => g_id}, socket) do
    zone = Enum.find(socket.assigns.zones, &(to_string(&1.id) == z_id))
    group = Enum.find(socket.assigns.zone_groups, &(to_string(&1.id) == g_id))
    {:ok, _} = Zones.add_zone_to_group(zone, group)
    {:noreply, assign(socket, :zones, Zones.list_zones())}
  end

  def handle_event("remove_zone_from_group", %{"zone_id" => z_id, "group_id" => g_id}, socket) do
    zone = Enum.find(socket.assigns.zones, &(to_string(&1.id) == z_id))
    group = Enum.find(socket.assigns.zone_groups, &(to_string(&1.id) == g_id))
    :ok = Zones.remove_zone_from_group(zone, group)
    {:noreply, assign(socket, :zones, Zones.list_zones())}
  end

  @impl true
  def handle_info({:close_test_zone, id}, socket) do
    zone = Enum.find(socket.assigns.zones, &(&1.id == id))
    ZoneDriver.deactivate(zone)
    {:noreply, assign(socket, :testing_zone_id, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6">
      <%= if @live_action in [:new, :edit] do %>
        <.zone_form changeset={@changeset} live_action={@live_action} />
      <% else %>
        <.zone_index
          zones={@zones}
          zone_groups={@zone_groups}
          testing_zone_id={@testing_zone_id}
        />
      <% end %>
    </div>
    """
  end

  defp zone_index(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-2xl font-bold">Zones</h1>
      <.link navigate={~p"/zones/new"} class="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-lg text-sm transition-colors">
        New zone
      </.link>
    </div>

    <div class="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden mb-8">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Number</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Node</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">GPIO Pin</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Groups</th>
            <th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <%= for zone <- @zones do %>
            <tr>
              <td class="px-4 py-3 text-sm text-gray-900"><%= zone.number %></td>
              <td class="px-4 py-3 text-sm text-gray-900"><%= zone.name %></td>
              <td class="px-4 py-3 text-sm text-gray-500 font-mono"><%= zone.node %></td>
              <td class="px-4 py-3 text-sm text-gray-500"><%= zone.gpio_pin %></td>
              <td class="px-4 py-3 text-sm text-gray-500">
                <%= Enum.map_join(zone.zone_groups, ", ", & &1.name) %>
              </td>
              <td class="px-4 py-3 text-sm space-x-2">
                <.link navigate={~p"/zones/#{zone.id}/edit"} class="text-blue-600 hover:text-blue-800 font-medium">
                  Edit
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={zone.id}
                  phx-confirm={"Delete zone \"#{zone.name}\"?"}
                  class="text-red-600 hover:text-red-800 font-medium"
                >
                  Delete
                </button>
                <button
                  phx-click="test_zone"
                  phx-value-id={zone.id}
                  class="text-gray-600 hover:text-gray-800 font-medium"
                  disabled={@testing_zone_id != nil}
                >
                  <%= if @testing_zone_id == zone.id do %>
                    Testing...
                  <% else %>
                    Test
                  <% end %>
                </button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>

    <section>
      <h2 class="text-lg font-semibold mb-4">Zone Groups</h2>

      <div class="space-y-4 mb-6">
        <%= for group <- @zone_groups do %>
          <div class="bg-white rounded-xl border border-gray-200 p-4">
            <div class="flex items-center justify-between mb-2">
              <span class="font-medium text-gray-900"><%= group.name %></span>
              <button
                phx-click="delete_group"
                phx-value-id={group.id}
                phx-confirm={"Delete group \"#{group.name}\"?"}
                class="text-red-600 hover:text-red-800 text-sm font-medium"
              >
                Delete
              </button>
            </div>
            <ul class="space-y-1">
              <%= for zone <- @zones, Enum.any?(zone.zone_groups, &(&1.id == group.id)) do %>
                <li class="flex items-center justify-between text-sm text-gray-600">
                  <span><%= zone.name %></span>
                  <button
                    phx-click="remove_zone_from_group"
                    phx-value-zone_id={zone.id}
                    phx-value-group_id={group.id}
                    class="text-red-500 hover:text-red-700 text-xs"
                  >
                    Remove
                  </button>
                </li>
              <% end %>
            </ul>
          </div>
        <% end %>
      </div>

      <.form for={%{}} phx-submit="create_group" class="flex gap-2">
        <input
          type="text"
          name="name"
          placeholder="New group name"
          required
          class="rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
        />
        <button
          type="submit"
          class="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-lg text-sm transition-colors"
        >
          New group
        </button>
      </.form>
    </section>
    """
  end

  defp zone_form(assigns) do
    ~H"""
    <div class="max-w-lg">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">
          <%= if @live_action == :new, do: "New Zone", else: "Edit Zone" %>
        </h1>
        <.link navigate={~p"/zones"} class="text-gray-500 hover:text-gray-700 text-sm">
          Cancel
        </.link>
      </div>

      <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
        <.form for={@changeset} phx-change="validate" phx-submit="save" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
            <input
              type="text"
              name="zone[name]"
              value={Ecto.Changeset.get_field(@changeset, :name)}
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
            />
            <%= for error <- Keyword.get_values(@changeset.errors, :name) do %>
              <p class="text-red-600 text-xs mt-1"><%= translate_error(error) %></p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Number</label>
            <input
              type="number"
              name="zone[number]"
              value={Ecto.Changeset.get_field(@changeset, :number)}
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
            />
            <%= for error <- Keyword.get_values(@changeset.errors, :number) do %>
              <p class="text-red-600 text-xs mt-1"><%= translate_error(error) %></p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Node</label>
            <select
              name="zone[node]"
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
            >
              <%= for n <- [node() | Node.list()] do %>
                <option
                  value={Atom.to_string(n)}
                  selected={Ecto.Changeset.get_field(@changeset, :node) == Atom.to_string(n)}
                >
                  <%= Atom.to_string(n) %>
                </option>
              <% end %>
            </select>
            <%= for error <- Keyword.get_values(@changeset.errors, :node) do %>
              <p class="text-red-600 text-xs mt-1"><%= translate_error(error) %></p>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">GPIO Pin (BCM)</label>
            <input
              type="number"
              name="zone[gpio_pin]"
              value={Ecto.Changeset.get_field(@changeset, :gpio_pin)}
              class="w-full rounded-lg border border-gray-300 px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-green-500"
            />
            <%= for error <- Keyword.get_values(@changeset.errors, :gpio_pin) do %>
              <p class="text-red-600 text-xs mt-1"><%= translate_error(error) %></p>
            <% end %>
          </div>

          <div class="flex items-center gap-2">
            <input
              type="checkbox"
              name="zone[active_low]"
              id="zone_active_low"
              value="true"
              checked={Ecto.Changeset.get_field(@changeset, :active_low) != false}
              class="rounded border-gray-300 text-green-600 focus:ring-green-500"
            />
            <label for="zone_active_low" class="text-sm font-medium text-gray-700">Active Low</label>
          </div>

          <button
            type="submit"
            class="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-lg text-sm transition-colors"
          >
            Save zone
          </button>
        </.form>
      </div>
    </div>
    """
  end

  defp translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end

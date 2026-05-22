defmodule NervesSprinklers.Zones do
  @moduledoc false

  import Ecto.Query

  alias NervesSprinklers.Gpio.GpioServer
  alias NervesSprinklers.Repo
  alias NervesSprinklers.Schema.{Zone, ZoneGroup, ZoneGroupMember}

  require Logger

  @remote_timeout 5_000

  def list_zones do
    Zone
    |> preload(:zone_groups)
    |> Repo.all()
  end

  def get_zone!(id) do
    Repo.get!(Zone, id)
  end

  def change_zone(%Zone{} = zone, attrs \\ %{}) do
    Zone.changeset(zone, attrs)
  end

  def get_zone_by_number!(number) do
    Repo.get_by!(Zone, number: number)
  end

  def create_zone(attrs) do
    %Zone{}
    |> Zone.changeset(attrs)
    |> Repo.insert()
    |> tap_gpio_add()
  end

  def update_zone(zone, attrs) do
    zone
    |> Zone.changeset(attrs)
    |> Repo.update()
  end

  def delete_zone(zone) do
    notify_gpio_remove(zone)

    Repo.delete(zone)
  end

  def zones_for_node(node_name) when is_atom(node_name) do
    node_string = Atom.to_string(node_name)

    Zone
    |> where([z], z.node == ^node_string)
    |> Repo.all()
  end

  def list_zone_groups do
    Repo.all(ZoneGroup)
  end

  def get_zone_group!(id) do
    Repo.get!(ZoneGroup, id)
  end

  def create_zone_group(attrs) do
    %ZoneGroup{}
    |> ZoneGroup.changeset(attrs)
    |> Repo.insert()
  end

  def update_zone_group(zone_group, attrs) do
    zone_group
    |> ZoneGroup.changeset(attrs)
    |> Repo.update()
  end

  def delete_zone_group(zone_group) do
    Repo.delete(zone_group)
  end

  def add_zone_to_group(zone, zone_group) do
    %ZoneGroupMember{}
    |> ZoneGroupMember.changeset(%{zone_id: zone.id, zone_group_id: zone_group.id})
    |> Repo.insert()
  end

  def remove_zone_from_group(zone, zone_group) do
    ZoneGroupMember
    |> where([m], m.zone_id == ^zone.id and m.zone_group_id == ^zone_group.id)
    |> Repo.delete_all()

    :ok
  end

  defp tap_gpio_add({:ok, zone} = result) do
    call_gpio(zone, {:add_pin, zone.gpio_pin})
    result
  end

  defp tap_gpio_add(error), do: error

  defp notify_gpio_remove(zone) do
    call_gpio(zone, {:remove_pin, zone.gpio_pin})
  end

  defp call_gpio(zone, msg) do
    node = String.to_atom(zone.node)
    GenServer.call({GpioServer, node}, msg, @remote_timeout)
  catch
    :exit, reason ->
      Logger.warning("Zones: GpioServer unreachable on #{zone.node}: #{inspect(reason)}")
  end
end

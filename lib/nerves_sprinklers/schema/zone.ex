defmodule NervesSprinklers.Schema.Zone do
  use Ecto.Schema
  import Ecto.Changeset

  alias NervesSprinklers.Schema.{ScheduleZone, ZoneGroup, ZoneGroupMember}

  schema "zones" do
    field(:number, :integer)
    field(:name, :string)
    field(:node, :string)
    field(:gpio_pin, :integer)
    field(:active_low, :boolean, default: true)

    has_many(:schedule_zones, ScheduleZone)
    many_to_many(:zone_groups, ZoneGroup, join_through: ZoneGroupMember)

    timestamps()
  end

  def changeset(zone, attrs) do
    zone
    |> cast(attrs, [:number, :name, :node, :gpio_pin, :active_low])
    |> validate_required([:number, :name, :node, :gpio_pin])
    |> validate_number(:gpio_pin, greater_than: 0)
    |> validate_length(:node, min: 1)
    |> unique_constraint(:number)
  end

  def node_atom(%__MODULE__{node: node}), do: String.to_existing_atom(node)
end

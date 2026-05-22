defmodule NervesSprinklers.Schema.ZoneGroup do
  use Ecto.Schema
  import Ecto.Changeset

  alias NervesSprinklers.Schema.{Zone, ZoneGroupMember}

  schema "zone_groups" do
    field(:name, :string)

    many_to_many(:zones, Zone, join_through: ZoneGroupMember)

    timestamps()
  end

  def changeset(zone_group, attrs) do
    zone_group
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end

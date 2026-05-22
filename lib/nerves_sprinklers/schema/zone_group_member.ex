defmodule NervesSprinklers.Schema.ZoneGroupMember do
  use Ecto.Schema
  import Ecto.Changeset

  alias NervesSprinklers.Schema.{Zone, ZoneGroup}

  schema "zone_group_members" do
    belongs_to(:zone, Zone)
    belongs_to(:zone_group, ZoneGroup)

    timestamps()
  end

  def changeset(member, attrs) do
    member
    |> cast(attrs, [:zone_id, :zone_group_id])
    |> validate_required([:zone_id, :zone_group_id])
    |> unique_constraint([:zone_id, :zone_group_id])
  end
end

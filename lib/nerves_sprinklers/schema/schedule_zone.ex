defmodule NervesSprinklers.Schema.ScheduleZone do
  use Ecto.Schema
  import Ecto.Changeset

  alias NervesSprinklers.Schema.{Schedule, Zone}

  schema "schedule_zones" do
    belongs_to(:schedule, Schedule)
    belongs_to(:zone, Zone)

    field(:position, :integer)
    field(:duration_sec, :integer)

    timestamps()
  end

  def changeset(schedule_zone, attrs) do
    schedule_zone
    |> cast(attrs, [:schedule_id, :zone_id, :position, :duration_sec])
    |> validate_required([:position, :duration_sec])
    |> validate_number(:position, greater_than_or_equal_to: 1)
    |> validate_number(:duration_sec, greater_than: 0)
  end
end

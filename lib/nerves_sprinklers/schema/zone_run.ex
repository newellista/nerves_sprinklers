defmodule NervesSprinklers.Schema.ZoneRun do
  use Ecto.Schema
  import Ecto.Changeset

  alias NervesSprinklers.Schema.ScheduleRun

  schema "zone_runs" do
    belongs_to(:schedule_run, ScheduleRun)

    field(:zone_number, :integer)
    field(:zone_name, :string)
    field(:planned_duration_sec, :integer)
    field(:actual_duration_sec, :integer)
    field(:status, Ecto.Enum, values: [:completed, :skipped, :error])

    timestamps()
  end

  def changeset(zone_run, attrs) do
    zone_run
    |> cast(attrs, [
      :schedule_run_id,
      :zone_number,
      :zone_name,
      :planned_duration_sec,
      :actual_duration_sec,
      :status
    ])
    |> validate_required([:zone_number, :zone_name, :planned_duration_sec, :status])
  end
end

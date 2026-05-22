defmodule NervesSprinklers.Schema.ScheduleRun do
  use Ecto.Schema
  import Ecto.Changeset

  alias NervesSprinklers.Schema.{Schedule, ZoneRun}

  schema "schedule_runs" do
    belongs_to(:schedule, Schedule)

    field(:schedule_name, :string)
    field(:trigger_type, Ecto.Enum, values: [:scheduled, :manual])
    field(:scheduled_at, :utc_datetime)
    field(:started_at, :utc_datetime)
    field(:completed_at, :utc_datetime)
    field(:status, Ecto.Enum, values: [:running, :completed, :aborted, :error])

    has_many(:zone_runs, ZoneRun)

    timestamps()
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :schedule_id,
      :schedule_name,
      :trigger_type,
      :scheduled_at,
      :started_at,
      :completed_at,
      :status
    ])
    |> validate_required([:schedule_name, :trigger_type, :status])
  end
end

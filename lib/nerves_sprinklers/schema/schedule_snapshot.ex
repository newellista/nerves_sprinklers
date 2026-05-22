defmodule NervesSprinklers.Schema.ScheduleSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  alias NervesSprinklers.Schema.Schedule

  schema "schedule_snapshots" do
    belongs_to(:schedule, Schedule)

    field(:version, :integer)
    field(:snapshot_json, :string)

    timestamps()
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [:schedule_id, :version, :snapshot_json])
    |> validate_required([:schedule_id, :version, :snapshot_json])
  end
end

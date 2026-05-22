defmodule NervesSprinklers.Schema.Schedule do
  use Ecto.Schema
  import Ecto.Changeset

  alias NervesSprinklers.Schema.{ScheduleRun, ScheduleSnapshot, ScheduleZone}

  schema "schedules" do
    field(:name, :string)
    field(:enabled, :boolean, default: true)
    field(:recurrence_type, Ecto.Enum, values: [:every_n_days, :days_of_week])
    field(:recurrence_days, :integer)
    field(:recurrence_dow, {:array, :integer})
    field(:start_date, :date)
    field(:start_time, :time)
    field(:seasonal_offset, :integer, default: 100)
    field(:paused_until, :date)

    has_many(:schedule_zones, ScheduleZone)
    has_many(:schedule_snapshots, ScheduleSnapshot)
    has_many(:schedule_runs, ScheduleRun)

    timestamps()
  end

  def changeset(schedule, attrs) do
    schedule
    |> cast(attrs, [
      :name,
      :enabled,
      :recurrence_type,
      :recurrence_days,
      :recurrence_dow,
      :start_date,
      :start_time,
      :seasonal_offset,
      :paused_until
    ])
    |> validate_required([:name, :recurrence_type, :start_date, :start_time])
    |> validate_number(:seasonal_offset, greater_than_or_equal_to: 1, less_than_or_equal_to: 200)
    |> validate_recurrence()
  end

  defp validate_recurrence(changeset) do
    case get_field(changeset, :recurrence_type) do
      :every_n_days ->
        changeset
        |> validate_required([:recurrence_days])
        |> validate_number(:recurrence_days, greater_than: 0)

      :days_of_week ->
        changeset
        |> validate_required([:recurrence_dow])
        |> validate_dow()

      _ ->
        changeset
    end
  end

  defp validate_dow(changeset) do
    case get_field(changeset, :recurrence_dow) do
      nil ->
        changeset

      [] ->
        add_error(changeset, :recurrence_dow, "must have at least one day")

      dow when is_list(dow) ->
        if Enum.all?(dow, &(&1 in 1..7)) do
          changeset
        else
          add_error(changeset, :recurrence_dow, "values must be integers 1–7")
        end
    end
  end
end

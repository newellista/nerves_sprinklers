defmodule NervesSprinklers.Schedules do
  @moduledoc false

  import Ecto.Query

  alias Ecto.Multi
  alias NervesSprinklers.Repo
  alias NervesSprinklers.Schema.{Schedule, ScheduleSnapshot, ScheduleZone}

  def list_schedules do
    Schedule
    |> preload(schedule_zones: :zone)
    |> Repo.all()
  end

  def get_schedule!(id) do
    Repo.get!(Schedule, id)
  end

  def list_schedule_zones(schedule) do
    ScheduleZone
    |> where([sz], sz.schedule_id == ^schedule.id)
    |> order_by([sz], sz.position)
    |> Repo.all()
  end

  def create_schedule(attrs) do
    Multi.new()
    |> Multi.insert(:schedule, Schedule.changeset(%Schedule{}, attrs))
    |> Multi.run(:snapshot, fn repo, %{schedule: schedule} ->
      insert_snapshot(repo, schedule.id, attrs)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{schedule: schedule}} ->
        # TODO: notify Scheduler
        {:ok, schedule}

      {:error, :schedule, changeset, _} ->
        {:error, changeset}

      {:error, _op, reason, _} ->
        {:error, reason}
    end
  end

  def update_schedule(schedule, attrs) do
    Multi.new()
    |> Multi.update(:schedule, Schedule.changeset(schedule, attrs))
    |> Multi.run(:snapshot, fn repo, %{schedule: updated} ->
      insert_snapshot(repo, updated.id, attrs)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{schedule: schedule}} ->
        # TODO: notify Scheduler
        {:ok, schedule}

      {:error, :schedule, changeset, _} ->
        {:error, changeset}

      {:error, _op, reason, _} ->
        {:error, reason}
    end
  end

  def delete_schedule(schedule) do
    Repo.delete(schedule)
  end

  def set_enabled(schedule, enabled) do
    {:ok, updated} = update_simple(schedule, %{enabled: enabled})
    {:ok, updated}
  end

  def pause_schedule(schedule, days) when is_integer(days) and days > 0 do
    paused_until = Date.add(Date.utc_today(), days)
    {:ok, updated} = update_simple(schedule, %{paused_until: paused_until})
    {:ok, updated}
  end

  def resume_schedule(schedule) do
    {:ok, updated} = update_simple(schedule, %{paused_until: nil})
    {:ok, updated}
  end

  def set_schedule_zones(schedule, zone_assignments) do
    zone_changesets =
      zone_assignments
      |> Enum.with_index(1)
      |> Enum.map(fn {%{zone_id: zone_id, duration_sec: duration_sec}, position} ->
        ScheduleZone.changeset(%ScheduleZone{}, %{
          schedule_id: schedule.id,
          zone_id: zone_id,
          position: position,
          duration_sec: duration_sec
        })
      end)

    snapshot_attrs = schedule_to_snapshot_attrs(schedule, zone_assignments)

    Multi.new()
    |> Multi.delete_all(:delete_zones, where(ScheduleZone, [sz], sz.schedule_id == ^schedule.id))
    |> Multi.run(:insert_zones, fn repo, _changes ->
      results = Enum.map(zone_changesets, &repo.insert/1)

      case Enum.find(results, &match?({:error, _}, &1)) do
        nil -> {:ok, Enum.map(results, fn {:ok, sz} -> sz end)}
        {:error, changeset} -> {:error, changeset}
      end
    end)
    |> Multi.run(:snapshot, fn repo, _changes ->
      insert_snapshot(repo, schedule.id, snapshot_attrs)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, _} ->
        # TODO: notify Scheduler
        {:ok, Repo.preload(Repo.get!(Schedule, schedule.id), schedule_zones: :zone)}

      {:error, _op, reason, _} ->
        {:error, reason}
    end
  end

  def change_schedule(%Schedule{} = schedule, attrs \\ %{}) do
    Schedule.changeset(schedule, attrs)
  end

  def list_snapshots(schedule_id) do
    ScheduleSnapshot
    |> where([s], s.schedule_id == ^schedule_id)
    |> order_by([s], s.version)
    |> Repo.all()
  end

  def get_snapshot!(id) do
    Repo.get!(ScheduleSnapshot, id)
  end

  defp insert_snapshot(repo, schedule_id, attrs) do
    max_version =
      ScheduleSnapshot
      |> where([s], s.schedule_id == ^schedule_id)
      |> repo.aggregate(:max, :version) || 0

    repo.insert(
      ScheduleSnapshot.changeset(%ScheduleSnapshot{}, %{
        schedule_id: schedule_id,
        version: max_version + 1,
        snapshot_json: Jason.encode!(stringify_keys(attrs))
      })
    )
  end

  defp update_simple(schedule, attrs) do
    schedule
    |> Schedule.changeset(attrs)
    |> Repo.update()
  end

  defp schedule_to_snapshot_attrs(schedule, zone_assignments) do
    %{
      name: schedule.name,
      enabled: schedule.enabled,
      recurrence_type: schedule.recurrence_type,
      recurrence_days: schedule.recurrence_days,
      recurrence_dow: schedule.recurrence_dow,
      start_date: schedule.start_date,
      start_time: schedule.start_time,
      seasonal_offset: schedule.seasonal_offset,
      paused_until: schedule.paused_until,
      zone_assignments: zone_assignments
    }
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), stringify_value(v)} end)
  end

  defp stringify_value(%Date{} = d), do: Date.to_iso8601(d)
  defp stringify_value(%Time{} = t), do: Time.to_iso8601(t)
  defp stringify_value(v) when is_map(v), do: stringify_keys(v)
  defp stringify_value(v) when is_list(v), do: Enum.map(v, &stringify_value/1)
  defp stringify_value(v) when is_atom(v) and not is_boolean(v) and v != nil, do: to_string(v)
  defp stringify_value(v), do: v
end

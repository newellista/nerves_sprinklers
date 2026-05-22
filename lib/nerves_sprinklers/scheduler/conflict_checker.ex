defmodule NervesSprinklers.Scheduler.ConflictChecker do
  @moduledoc false

  alias NervesSprinklers.Scheduler.Recurrence
  alias NervesSprinklers.Schema.Schedule

  @spec check(Schedule.t(), [Schedule.t()]) ::
          :ok
          | {:conflict, %{schedule: Schedule.t(), day: Date.t(), overlap_minutes: integer()}}
  def check(candidate, existing) do
    today = Date.utc_today()
    all_schedules = [candidate | reject_self(existing, candidate.id)]

    Enum.find_value(0..27, :ok, fn offset ->
      date = Date.add(today, offset)
      active = Enum.filter(all_schedules, &Recurrence.runs_on?(&1, date))
      find_conflict(active, date)
    end)
  end

  defp reject_self(schedules, nil), do: schedules
  defp reject_self(schedules, id), do: Enum.reject(schedules, &(&1.id == id))

  defp find_conflict(schedules, date) do
    pairs =
      for a <- schedules,
          b <- schedules,
          a.id < b.id or is_nil(a.id) or is_nil(b.id),
          a != b,
          do: {a, b}

    Enum.find_value(pairs, &overlapping_pair(&1, date))
  end

  defp overlapping_pair({a, b}, date) do
    shared_zones = MapSet.intersection(zone_ids(a), zone_ids(b))

    if MapSet.size(shared_zones) > 0 do
      windows_conflict(a, b, date)
    end
  end

  defp windows_conflict(a, b, date) do
    {start_a, end_a} = window(a)
    {start_b, end_b} = window(b)

    if start_a < end_b and start_b < end_a do
      overlap_secs = min(end_a, end_b) - max(start_a, start_b)
      {:conflict, %{schedule: b, day: date, overlap_minutes: div(overlap_secs, 60)}}
    end
  end

  defp zone_ids(%Schedule{schedule_zones: zones}), do: MapSet.new(zones, & &1.zone_id)

  defp window(%Schedule{start_time: t, schedule_zones: zones, seasonal_offset: offset}) do
    start_sec = t.hour * 3600 + t.minute * 60 + t.second
    total_sec = Enum.sum(Enum.map(zones, &round(&1.duration_sec * offset / 100)))
    {start_sec, start_sec + total_sec}
  end
end

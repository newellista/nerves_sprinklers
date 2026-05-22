defmodule NervesSprinklers.Scheduler.Recurrence do
  @moduledoc false

  alias NervesSprinklers.Schema.Schedule

  @spec runs_on?(Schedule.t(), Date.t()) :: boolean
  def runs_on?(schedule, date) do
    schedule.enabled and
      not paused?(schedule, date) and
      not before_start?(schedule, date) and
      matches_recurrence?(schedule, date)
  end

  @spec next_run_after(Schedule.t(), DateTime.t(), String.t()) :: DateTime.t() | nil
  def next_run_after(%Schedule{enabled: false}, _after_dt, _timezone), do: nil

  def next_run_after(schedule, after_dt, timezone) do
    today = DateTime.to_date(Timex.now(timezone))

    Enum.find_value(0..365, fn offset ->
      date = Date.add(today, offset)
      candidate_dt(schedule, date, timezone, after_dt)
    end)
  end

  defp candidate_dt(schedule, date, timezone, after_dt) do
    if runs_on?(schedule, date) do
      naive = NaiveDateTime.new!(date, schedule.start_time)
      local_dt = Timex.to_datetime(naive, timezone)
      utc_dt = Timex.Timezone.convert(local_dt, "UTC")
      if DateTime.compare(utc_dt, after_dt) == :gt, do: utc_dt
    end
  end

  defp paused?(%Schedule{paused_until: nil}, _date), do: false

  defp paused?(%Schedule{paused_until: paused_until}, date),
    do: Date.compare(date, paused_until) != :gt

  defp before_start?(%Schedule{start_date: start_date}, date),
    do: Date.compare(date, start_date) == :lt

  defp matches_recurrence?(%Schedule{recurrence_type: :every_n_days} = schedule, date) do
    diff = Date.diff(date, schedule.start_date)
    diff >= 0 and rem(diff, schedule.recurrence_days) == 0
  end

  defp matches_recurrence?(%Schedule{recurrence_type: :days_of_week} = schedule, date) do
    Date.day_of_week(date) in schedule.recurrence_dow
  end
end

defmodule NervesSprinklers.Scheduler.RecurrenceTest do
  use ExUnit.Case, async: true

  alias NervesSprinklers.Scheduler.Recurrence
  alias NervesSprinklers.Schema.Schedule
  alias NervesSprinklers.Schema.ScheduleZone

  defp schedule(opts \\ []) do
    struct(
      Schedule,
      Keyword.merge(
        [
          id: 1,
          name: "Test",
          enabled: true,
          recurrence_type: :every_n_days,
          recurrence_days: 1,
          start_date: ~D[2020-01-01],
          start_time: ~T[06:00:00],
          seasonal_offset: 100,
          paused_until: nil,
          schedule_zones: [
            struct(ScheduleZone, %{zone_id: 1, position: 1, duration_sec: 600})
          ]
        ],
        opts
      )
    )
  end

  describe "runs_on?/2 — every_n_days" do
    test "returns true when date is exactly on start_date" do
      s = schedule(recurrence_days: 3, start_date: ~D[2024-01-01])
      assert Recurrence.runs_on?(s, ~D[2024-01-01])
    end

    test "returns true when date is an exact multiple of recurrence_days from start_date" do
      s = schedule(recurrence_days: 3, start_date: ~D[2024-01-01])
      assert Recurrence.runs_on?(s, ~D[2024-01-04])
      assert Recurrence.runs_on?(s, ~D[2024-01-07])
    end

    test "returns false when date is not on a recurrence interval" do
      s = schedule(recurrence_days: 3, start_date: ~D[2024-01-01])
      refute Recurrence.runs_on?(s, ~D[2024-01-02])
      refute Recurrence.runs_on?(s, ~D[2024-01-03])
    end

    test "returns false when date is before start_date" do
      s = schedule(recurrence_days: 1, start_date: ~D[2024-06-01])
      refute Recurrence.runs_on?(s, ~D[2024-05-31])
    end
  end

  describe "runs_on?/2 — days_of_week" do
    test "returns true when date's day of week is in recurrence_dow" do
      s = schedule(recurrence_type: :days_of_week, recurrence_dow: [1, 3, 5])
      assert Recurrence.runs_on?(s, ~D[2024-01-01])
      assert Recurrence.runs_on?(s, ~D[2024-01-03])
      assert Recurrence.runs_on?(s, ~D[2024-01-05])
    end

    test "returns false when date's day of week is not in recurrence_dow" do
      s = schedule(recurrence_type: :days_of_week, recurrence_dow: [1, 3, 5])
      refute Recurrence.runs_on?(s, ~D[2024-01-02])
      refute Recurrence.runs_on?(s, ~D[2024-01-04])
      refute Recurrence.runs_on?(s, ~D[2024-01-06])
    end

    test "returns false when date is before start_date" do
      s =
        schedule(recurrence_type: :days_of_week, recurrence_dow: [1], start_date: ~D[2024-01-08])

      refute Recurrence.runs_on?(s, ~D[2024-01-01])
    end
  end

  describe "runs_on?/2 — disabled and paused" do
    test "returns false when schedule is disabled" do
      s = schedule(enabled: false)
      refute Recurrence.runs_on?(s, ~D[2024-01-01])
    end

    test "returns false when date is on or before paused_until" do
      s = schedule(paused_until: ~D[2024-03-01])
      refute Recurrence.runs_on?(s, ~D[2024-02-15])
      refute Recurrence.runs_on?(s, ~D[2024-03-01])
    end

    test "returns true when date is after paused_until" do
      s = schedule(paused_until: ~D[2024-03-01])
      assert Recurrence.runs_on?(s, ~D[2024-03-02])
    end
  end

  describe "next_run_after/3" do
    test "returns nil for a disabled schedule" do
      s = schedule(enabled: false)
      after_dt = DateTime.utc_now()
      assert Recurrence.next_run_after(s, after_dt, "UTC") == nil
    end

    test "returns the next scheduled datetime after the given datetime" do
      s = schedule(recurrence_days: 1, start_date: ~D[2020-01-01], start_time: ~T[06:00:00])
      after_dt = %{DateTime.utc_now() | hour: 8, minute: 0, second: 0, microsecond: {0, 0}}
      result = Recurrence.next_run_after(s, after_dt, "UTC")
      assert %DateTime{} = result
      assert DateTime.compare(result, after_dt) == :gt
    end

    test "returns a run that is strictly after the given datetime, not equal" do
      today = Date.utc_today()
      s = schedule(recurrence_days: 1, start_date: ~D[2020-01-01], start_time: ~T[06:00:00])

      run_dt = DateTime.new!(today, ~T[06:00:00], "Etc/UTC")
      just_before = DateTime.add(run_dt, -1, :second)

      result = Recurrence.next_run_after(s, just_before, "UTC")
      assert result != nil
      assert DateTime.compare(result, just_before) == :gt
    end
  end
end

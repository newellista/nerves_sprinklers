defmodule NervesSprinklers.Scheduler.ConflictCheckerTest do
  use ExUnit.Case, async: true

  alias NervesSprinklers.Scheduler.ConflictChecker
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

  describe "check/2 — no conflict" do
    test "returns :ok when there are no existing schedules" do
      candidate = schedule(id: nil)
      assert ConflictChecker.check(candidate, []) == :ok
    end

    test "returns :ok when schedules share a zone but windows do not overlap" do
      candidate = schedule(id: 1, start_time: ~T[06:00:00])
      existing = [schedule(id: 2, start_time: ~T[07:00:00])]
      assert ConflictChecker.check(candidate, existing) == :ok
    end

    test "returns :ok when windows overlap but schedules share no zones" do
      candidate =
        schedule(
          id: 1,
          start_time: ~T[06:00:00],
          schedule_zones: [struct(ScheduleZone, %{zone_id: 1, position: 1, duration_sec: 600})]
        )

      existing = [
        schedule(
          id: 2,
          start_time: ~T[06:00:00],
          schedule_zones: [struct(ScheduleZone, %{zone_id: 2, position: 1, duration_sec: 600})]
        )
      ]

      assert ConflictChecker.check(candidate, existing) == :ok
    end

    test "returns :ok when existing schedule is paused" do
      candidate = schedule(id: 1, start_time: ~T[06:00:00])

      existing = [
        schedule(
          id: 2,
          start_time: ~T[06:00:00],
          paused_until: ~D[2099-12-31]
        )
      ]

      assert ConflictChecker.check(candidate, existing) == :ok
    end

    test "returns :ok when days_of_week schedules run on different days" do
      candidate =
        schedule(
          id: 1,
          recurrence_type: :days_of_week,
          recurrence_dow: [1, 3, 5],
          start_time: ~T[06:00:00]
        )

      existing = [
        schedule(
          id: 2,
          recurrence_type: :days_of_week,
          recurrence_dow: [2, 4, 6],
          start_time: ~T[06:00:00]
        )
      ]

      assert ConflictChecker.check(candidate, existing) == :ok
    end
  end

  describe "check/2 — conflict detected" do
    test "returns conflict when same zone and overlapping windows (every_n_days)" do
      candidate = schedule(id: 1, start_time: ~T[06:00:00])
      existing = [schedule(id: 2, start_time: ~T[06:05:00])]

      assert {:conflict, %{schedule: _, day: _, overlap_minutes: minutes}} =
               ConflictChecker.check(candidate, existing)

      assert minutes > 0
    end

    test "returns conflict for candidate with nil id (being created)" do
      candidate = schedule(id: nil, start_time: ~T[06:00:00])
      existing = [schedule(id: 1, start_time: ~T[06:05:00])]

      assert {:conflict, %{schedule: _, day: _, overlap_minutes: minutes}} =
               ConflictChecker.check(candidate, existing)

      assert minutes > 0
    end

    test "overlap_minutes is calculated correctly" do
      candidate =
        schedule(
          id: 1,
          start_time: ~T[06:00:00],
          schedule_zones: [struct(ScheduleZone, %{zone_id: 1, position: 1, duration_sec: 3600})]
        )

      existing = [
        schedule(
          id: 2,
          start_time: ~T[06:30:00],
          schedule_zones: [struct(ScheduleZone, %{zone_id: 1, position: 1, duration_sec: 3600})]
        )
      ]

      assert {:conflict, %{overlap_minutes: minutes}} = ConflictChecker.check(candidate, existing)
      assert minutes == 30
    end

    test "returns conflict when days_of_week schedules share a day and zone" do
      candidate =
        schedule(
          id: 1,
          recurrence_type: :days_of_week,
          recurrence_dow: [1, 2, 3, 4, 5, 6, 7],
          start_time: ~T[06:00:00]
        )

      existing = [
        schedule(
          id: 2,
          recurrence_type: :days_of_week,
          recurrence_dow: [1, 2, 3, 4, 5, 6, 7],
          start_time: ~T[06:05:00]
        )
      ]

      assert {:conflict, _} = ConflictChecker.check(candidate, existing)
    end

    test "does not compare candidate against itself when id is present" do
      candidate = schedule(id: 1, start_time: ~T[06:00:00])
      existing = [candidate]

      assert ConflictChecker.check(candidate, existing) == :ok
    end
  end

  describe "check/2 — seasonal_offset affects window" do
    test "shorter effective duration does not overlap with offset at 50%" do
      candidate =
        schedule(
          id: 1,
          start_time: ~T[06:00:00],
          seasonal_offset: 50,
          schedule_zones: [struct(ScheduleZone, %{zone_id: 1, position: 1, duration_sec: 600})]
        )

      existing = [
        schedule(
          id: 2,
          start_time: ~T[06:05:00],
          seasonal_offset: 100,
          schedule_zones: [struct(ScheduleZone, %{zone_id: 1, position: 1, duration_sec: 600})]
        )
      ]

      assert ConflictChecker.check(candidate, existing) == :ok
    end
  end
end

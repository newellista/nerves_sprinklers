defmodule NervesSprinklers.HistoryTest do
  use NervesSprinklers.DataCase

  alias NervesSprinklers.History
  alias NervesSprinklers.Schema.{ScheduleRun, ZoneRun}

  defp insert_run(attrs \\ %{}) do
    defaults = %{
      schedule_name: "Morning",
      trigger_type: :manual,
      started_at: DateTime.utc_now(),
      status: :completed
    }

    Repo.insert!(%ScheduleRun{} |> ScheduleRun.changeset(Map.merge(defaults, attrs)))
  end

  describe "list_schedule_runs/1" do
    test "returns runs newest first" do
      insert_run(%{schedule_name: "First"})
      insert_run(%{schedule_name: "Second"})
      [a, b] = History.list_schedule_runs()
      assert a.schedule_name == "Second"
      assert b.schedule_name == "First"
    end

    test "respects limit" do
      Enum.each(1..5, fn i -> insert_run(%{schedule_name: "Run #{i}"}) end)
      assert length(History.list_schedule_runs(limit: 3)) == 3
    end

    test "respects offset" do
      Enum.each(1..5, fn i -> insert_run(%{schedule_name: "Run #{i}"}) end)
      page1 = History.list_schedule_runs(limit: 2, offset: 0)
      page2 = History.list_schedule_runs(limit: 2, offset: 2)
      refute Enum.any?(page1, fn r -> r.id in Enum.map(page2, & &1.id) end)
    end

    test "preloads zone_runs" do
      run = insert_run()

      Repo.insert!(
        %ZoneRun{}
        |> ZoneRun.changeset(%{
          schedule_run_id: run.id,
          zone_number: 1,
          zone_name: "Zone 1",
          planned_duration_sec: 60,
          actual_duration_sec: 58,
          status: :completed
        })
      )

      [fetched] = History.list_schedule_runs()
      assert length(fetched.zone_runs) == 1
    end

    test "returns empty list when no runs" do
      assert History.list_schedule_runs() == []
    end
  end

  describe "count_schedule_runs/0" do
    test "returns 0 when empty" do
      assert History.count_schedule_runs() == 0
    end

    test "returns correct count" do
      insert_run()
      insert_run()
      assert History.count_schedule_runs() == 2
    end
  end
end

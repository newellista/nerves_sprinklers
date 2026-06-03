defmodule NervesSprinklers.Scheduler.SchedulerTest do
  use NervesSprinklers.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias NervesSprinklers.Scheduler.Scheduler
  alias NervesSprinklers.Schedules

  @valid_attrs %{
    name: "Test Schedule",
    recurrence_type: :every_n_days,
    recurrence_days: 1,
    start_date: ~D[2025-01-01],
    start_time: ~T[06:00:00]
  }

  setup do
    pid = start_supervised!(Scheduler)
    # Allow the Scheduler to access the sandbox DB connection
    Sandbox.allow(NervesSprinklers.Repo, self(), pid)
    # Wait for the initial :reload_all to complete
    Process.sleep(50)
    {:ok, scheduler: pid}
  end

  describe "reload/0" do
    test "does not crash when no schedules exist", %{scheduler: pid} do
      Scheduler.reload()
      Process.sleep(50)
      assert Process.alive?(pid)
    end

    test "disabled schedule gets no timer fired" do
      {:ok, _} = Schedules.create_schedule(Map.put(@valid_attrs, :enabled, false))
      Scheduler.reload()
      refute_receive {:schedule_timer_fired, _}, 100
    end

    test "does not crash with an enabled schedule", %{scheduler: pid} do
      {:ok, _} = Schedules.create_schedule(@valid_attrs)
      Scheduler.reload()
      Process.sleep(50)
      assert Process.alive?(pid)
    end
  end
end

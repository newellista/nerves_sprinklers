defmodule NervesSprinklers.SchedulesTest do
  use NervesSprinklers.DataCase

  alias NervesSprinklers.Schedules
  alias NervesSprinklers.Schema.{Schedule, ScheduleSnapshot, Zone}

  @valid_attrs %{
    name: "Morning",
    recurrence_type: :every_n_days,
    recurrence_days: 3,
    start_date: ~D[2025-01-01],
    start_time: ~T[06:00:00]
  }

  defp insert_zone(number) do
    Repo.insert!(%Zone{
      number: number,
      name: "Zone #{number}",
      node: "n@h",
      gpio_pin: 17 + number
    })
  end

  defp insert_schedule(attrs \\ %{}) do
    {:ok, schedule} = Schedules.create_schedule(Map.merge(@valid_attrs, attrs))
    schedule
  end

  describe "list_schedules/0" do
    test "returns all schedules with preloaded schedule_zones" do
      insert_schedule()
      insert_schedule(%{name: "Evening", start_time: ~T[18:00:00]})
      schedules = Schedules.list_schedules()
      assert length(schedules) == 2
      assert Enum.all?(schedules, fn s -> is_list(s.schedule_zones) end)
    end

    test "returns empty list when no schedules" do
      assert Schedules.list_schedules() == []
    end
  end

  describe "get_schedule!/1" do
    test "returns schedule by id" do
      schedule = insert_schedule()
      found = Schedules.get_schedule!(schedule.id)
      assert found.id == schedule.id
      assert found.name == "Morning"
    end

    test "raises on missing id" do
      assert_raise Ecto.NoResultsError, fn -> Schedules.get_schedule!(0) end
    end
  end

  describe "create_schedule/1" do
    test "creates schedule with valid attrs" do
      assert {:ok, %Schedule{name: "Morning"}} = Schedules.create_schedule(@valid_attrs)
    end

    test "returns error changeset with invalid attrs" do
      assert {:error, changeset} = Schedules.create_schedule(%{name: "bad"})
      refute changeset.valid?
    end

    test "creates a snapshot row on success" do
      before_count = Repo.aggregate(ScheduleSnapshot, :count)
      {:ok, _} = Schedules.create_schedule(@valid_attrs)
      assert Repo.aggregate(ScheduleSnapshot, :count) == before_count + 1
    end

    test "snapshot has version 1 for new schedule" do
      {:ok, schedule} = Schedules.create_schedule(@valid_attrs)
      [snapshot] = Schedules.list_snapshots(schedule.id)
      assert snapshot.version == 1
    end

    test "does not create snapshot when validation fails" do
      before_count = Repo.aggregate(ScheduleSnapshot, :count)
      {:error, _} = Schedules.create_schedule(%{})
      assert Repo.aggregate(ScheduleSnapshot, :count) == before_count
    end
  end

  describe "update_schedule/2" do
    test "updates schedule fields" do
      schedule = insert_schedule()
      assert {:ok, updated} = Schedules.update_schedule(schedule, %{name: "Updated"})
      assert updated.name == "Updated"
    end

    test "returns error changeset on invalid update" do
      schedule = insert_schedule()

      assert {:error, changeset} =
               Schedules.update_schedule(schedule, %{recurrence_type: nil})

      refute changeset.valid?
    end

    test "creates a snapshot row on update" do
      schedule = insert_schedule()
      before_count = Repo.aggregate(ScheduleSnapshot, :count)
      {:ok, _} = Schedules.update_schedule(schedule, %{name: "Updated"})
      assert Repo.aggregate(ScheduleSnapshot, :count) == before_count + 1
    end

    test "snapshot version increments on each update" do
      {:ok, schedule} = Schedules.create_schedule(@valid_attrs)
      {:ok, _} = Schedules.update_schedule(schedule, %{name: "V2"})
      {:ok, _} = Schedules.update_schedule(schedule, %{name: "V3"})
      snapshots = Schedules.list_snapshots(schedule.id)
      assert length(snapshots) == 3
      assert Enum.map(snapshots, & &1.version) == [1, 2, 3]
    end
  end

  describe "delete_schedule/1" do
    test "deletes the schedule" do
      schedule = insert_schedule()
      assert {:ok, _} = Schedules.delete_schedule(schedule)
      assert_raise Ecto.NoResultsError, fn -> Schedules.get_schedule!(schedule.id) end
    end
  end

  describe "set_enabled/2" do
    test "disables a schedule" do
      schedule = insert_schedule()
      assert {:ok, updated} = Schedules.set_enabled(schedule, false)
      refute updated.enabled
    end

    test "enables a schedule" do
      schedule = insert_schedule(%{enabled: false})
      assert {:ok, updated} = Schedules.set_enabled(schedule, true)
      assert updated.enabled
    end
  end

  describe "pause_schedule/2" do
    test "sets paused_until to today + days" do
      schedule = insert_schedule()
      assert {:ok, updated} = Schedules.pause_schedule(schedule, 7)
      assert updated.paused_until == Date.add(Date.utc_today(), 7)
    end
  end

  describe "resume_schedule/1" do
    test "clears paused_until" do
      schedule = insert_schedule()
      {:ok, paused} = Schedules.pause_schedule(schedule, 3)
      assert {:ok, resumed} = Schedules.resume_schedule(paused)
      assert is_nil(resumed.paused_until)
    end
  end

  describe "set_schedule_zones/2" do
    test "inserts zone assignments with positions" do
      schedule = insert_schedule()
      zone1 = insert_zone(1)
      zone2 = insert_zone(2)

      assignments = [
        %{zone_id: zone1.id, duration_sec: 300},
        %{zone_id: zone2.id, duration_sec: 600}
      ]

      assert {:ok, updated} = Schedules.set_schedule_zones(schedule, assignments)
      assert length(updated.schedule_zones) == 2

      sorted = Enum.sort_by(updated.schedule_zones, & &1.position)
      assert Enum.at(sorted, 0).position == 1
      assert Enum.at(sorted, 0).duration_sec == 300
      assert Enum.at(sorted, 1).position == 2
      assert Enum.at(sorted, 1).duration_sec == 600
    end

    test "replaces existing zone assignments" do
      schedule = insert_schedule()
      zone1 = insert_zone(1)
      zone2 = insert_zone(2)

      {:ok, _} =
        Schedules.set_schedule_zones(schedule, [%{zone_id: zone1.id, duration_sec: 300}])

      {:ok, updated} =
        Schedules.set_schedule_zones(schedule, [%{zone_id: zone2.id, duration_sec: 120}])

      assert length(updated.schedule_zones) == 1
      assert hd(updated.schedule_zones).zone_id == zone2.id
    end

    test "creates a snapshot row on set_schedule_zones" do
      schedule = insert_schedule()
      zone = insert_zone(3)
      before_count = Repo.aggregate(ScheduleSnapshot, :count)

      {:ok, _} =
        Schedules.set_schedule_zones(schedule, [%{zone_id: zone.id, duration_sec: 60}])

      assert Repo.aggregate(ScheduleSnapshot, :count) == before_count + 1
    end

    test "snapshot version increments on set_schedule_zones" do
      {:ok, schedule} = Schedules.create_schedule(@valid_attrs)
      zone = insert_zone(4)

      {:ok, _} =
        Schedules.set_schedule_zones(schedule, [%{zone_id: zone.id, duration_sec: 60}])

      snapshots = Schedules.list_snapshots(schedule.id)
      assert length(snapshots) == 2
      assert Enum.at(snapshots, 1).version == 2
    end
  end

  describe "list_snapshots/1" do
    test "returns snapshots ordered by version" do
      {:ok, schedule} = Schedules.create_schedule(@valid_attrs)
      {:ok, _} = Schedules.update_schedule(schedule, %{name: "V2"})
      snapshots = Schedules.list_snapshots(schedule.id)
      assert length(snapshots) == 2
      assert Enum.at(snapshots, 0).version < Enum.at(snapshots, 1).version
    end

    test "returns empty list for schedule with no snapshots manually checked" do
      {:ok, schedule} = Schedules.create_schedule(@valid_attrs)
      snapshots = Schedules.list_snapshots(schedule.id)
      assert length(snapshots) == 1
    end
  end

  describe "get_snapshot!/1" do
    test "returns snapshot by id" do
      {:ok, schedule} = Schedules.create_schedule(@valid_attrs)
      [snapshot] = Schedules.list_snapshots(schedule.id)
      found = Schedules.get_snapshot!(snapshot.id)
      assert found.id == snapshot.id
    end

    test "raises on missing id" do
      assert_raise Ecto.NoResultsError, fn -> Schedules.get_snapshot!(0) end
    end
  end
end

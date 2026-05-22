defmodule NervesSprinklers.Schema.ScheduleTest do
  use NervesSprinklers.DataCase, async: true

  alias NervesSprinklers.Schema.Schedule

  @valid_every_n %{
    name: "Morning",
    recurrence_type: :every_n_days,
    recurrence_days: 3,
    start_date: ~D[2025-01-01],
    start_time: ~T[06:00:00]
  }

  @valid_dow %{
    name: "Weekly",
    recurrence_type: :days_of_week,
    recurrence_dow: [1, 3, 5],
    start_date: ~D[2025-01-01],
    start_time: ~T[07:00:00]
  }

  describe "changeset/2 — every_n_days" do
    test "valid attrs" do
      assert Schedule.changeset(%Schedule{}, @valid_every_n).valid?
    end

    test "requires recurrence_days" do
      cs = Schedule.changeset(%Schedule{}, Map.delete(@valid_every_n, :recurrence_days))
      refute cs.valid?
      assert "can't be blank" in errors_on(cs).recurrence_days
    end

    test "recurrence_days must be > 0" do
      cs = Schedule.changeset(%Schedule{}, Map.put(@valid_every_n, :recurrence_days, 0))
      refute cs.valid?
    end
  end

  describe "changeset/2 — days_of_week" do
    test "valid attrs" do
      assert Schedule.changeset(%Schedule{}, @valid_dow).valid?
    end

    test "requires recurrence_dow" do
      cs = Schedule.changeset(%Schedule{}, Map.delete(@valid_dow, :recurrence_dow))
      refute cs.valid?
    end

    test "empty recurrence_dow is invalid" do
      cs = Schedule.changeset(%Schedule{}, Map.put(@valid_dow, :recurrence_dow, []))
      refute cs.valid?
      assert "must have at least one day" in errors_on(cs).recurrence_dow
    end

    test "values outside 1–7 are invalid" do
      cs = Schedule.changeset(%Schedule{}, Map.put(@valid_dow, :recurrence_dow, [0, 8]))
      refute cs.valid?
    end
  end

  describe "changeset/2 — general" do
    test "seasonal_offset must be 1–200" do
      low = Schedule.changeset(%Schedule{}, Map.put(@valid_every_n, :seasonal_offset, 0))
      high = Schedule.changeset(%Schedule{}, Map.put(@valid_every_n, :seasonal_offset, 201))
      refute low.valid?
      refute high.valid?
    end

    test "requires name, recurrence_type, start_date, start_time" do
      cs = Schedule.changeset(%Schedule{}, %{})
      refute cs.valid?
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end

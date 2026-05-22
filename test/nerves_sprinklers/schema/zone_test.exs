defmodule NervesSprinklers.Schema.ZoneTest do
  use NervesSprinklers.DataCase, async: true

  alias NervesSprinklers.Schema.Zone

  describe "changeset/2" do
    test "valid attrs" do
      cs =
        Zone.changeset(%Zone{}, %{
          number: 1,
          name: "Front",
          node: "sprinklers@nerves.local",
          gpio_pin: 17
        })

      assert cs.valid?
    end

    test "requires number, name, node, gpio_pin" do
      cs = Zone.changeset(%Zone{}, %{})
      refute cs.valid?
      assert errors_on(cs) |> Map.keys() |> Enum.sort() == [:gpio_pin, :name, :node, :number]
    end

    test "gpio_pin must be > 0" do
      cs = Zone.changeset(%Zone{}, %{number: 1, name: "F", node: "n@h", gpio_pin: 0})
      refute cs.valid?
      assert "must be greater than 0" in errors_on(cs).gpio_pin
    end

    test "node must be non-empty" do
      cs = Zone.changeset(%Zone{}, %{number: 1, name: "F", node: "", gpio_pin: 17})
      refute cs.valid?
    end

    test "active_low defaults to true" do
      cs = Zone.changeset(%Zone{}, %{number: 1, name: "F", node: "n@h", gpio_pin: 17})
      assert Ecto.Changeset.get_field(cs, :active_low) == true
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

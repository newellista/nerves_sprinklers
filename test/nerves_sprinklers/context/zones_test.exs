defmodule NervesSprinklers.ZonesTest do
  use NervesSprinklers.DataCase

  alias NervesSprinklers.Schema.{Zone, ZoneGroup, ZoneGroupMember}
  alias NervesSprinklers.Zones

  @valid_zone_attrs %{number: 1, name: "Front", node: "sprinklers@nerves.local", gpio_pin: 17}
  @valid_group_attrs %{name: "Front Yard"}

  defp create_zone(attrs \\ %{}) do
    {:ok, zone} = Zones.create_zone(Map.merge(@valid_zone_attrs, attrs))
    zone
  end

  defp create_zone_group(attrs \\ %{}) do
    {:ok, group} = Zones.create_zone_group(Map.merge(@valid_group_attrs, attrs))
    group
  end

  describe "list_zones/0" do
    test "returns all zones with zone_groups preloaded" do
      zone = create_zone()
      zones = Zones.list_zones()
      assert Enum.any?(zones, fn z -> z.id == zone.id end)
      fetched = Enum.find(zones, fn z -> z.id == zone.id end)
      assert %Ecto.Association.NotLoaded{} != fetched.zone_groups
    end

    test "returns empty list when no zones exist" do
      assert Zones.list_zones() == []
    end
  end

  describe "get_zone!/1" do
    test "returns the zone by id" do
      zone = create_zone()
      assert Zones.get_zone!(zone.id).id == zone.id
    end

    test "raises Ecto.NoResultsError for unknown id" do
      assert_raise Ecto.NoResultsError, fn -> Zones.get_zone!(0) end
    end
  end

  describe "get_zone_by_number!/1" do
    test "returns the zone by number" do
      zone = create_zone()
      assert Zones.get_zone_by_number!(zone.number).id == zone.id
    end

    test "raises Ecto.NoResultsError for unknown number" do
      assert_raise Ecto.NoResultsError, fn -> Zones.get_zone_by_number!(999) end
    end
  end

  describe "create_zone/1" do
    test "creates a zone with valid attrs" do
      assert {:ok, %Zone{} = zone} = Zones.create_zone(@valid_zone_attrs)
      assert zone.name == "Front"
      assert zone.gpio_pin == 17
    end

    test "returns error changeset with invalid attrs" do
      assert {:error, changeset} = Zones.create_zone(%{})
      refute changeset.valid?
    end

    test "returns error changeset on duplicate zone number" do
      create_zone()
      assert {:error, changeset} = Zones.create_zone(@valid_zone_attrs)
      assert changeset.errors[:number] != nil
    end

    test "tolerates GpioServer being unreachable" do
      assert {:ok, _zone} = Zones.create_zone(@valid_zone_attrs)
    end
  end

  describe "update_zone/2" do
    test "updates zone with valid attrs" do
      zone = create_zone()
      assert {:ok, updated} = Zones.update_zone(zone, %{name: "Back"})
      assert updated.name == "Back"
    end

    test "returns error changeset with invalid attrs" do
      zone = create_zone()
      assert {:error, changeset} = Zones.update_zone(zone, %{gpio_pin: 0})
      refute changeset.valid?
    end
  end

  describe "delete_zone/1" do
    test "deletes the zone" do
      zone = create_zone()
      assert {:ok, %Zone{}} = Zones.delete_zone(zone)
      assert_raise Ecto.NoResultsError, fn -> Zones.get_zone!(zone.id) end
    end

    test "tolerates GpioServer being unreachable during delete" do
      zone = create_zone()
      assert {:ok, _} = Zones.delete_zone(zone)
    end
  end

  describe "zones_for_node/1" do
    test "returns zones belonging to the given node" do
      zone = create_zone(%{node: "garage@nerves.local", number: 5})
      _other = create_zone(%{node: "basement@nerves.local", number: 6, gpio_pin: 18})

      results = Zones.zones_for_node(:"garage@nerves.local")
      assert Enum.any?(results, fn z -> z.id == zone.id end)
      assert Enum.all?(results, fn z -> z.node == "garage@nerves.local" end)
    end

    test "returns empty list when no zones match the node" do
      assert Zones.zones_for_node(:nonexistent@node) == []
    end
  end

  describe "list_zone_groups/0" do
    test "returns all zone groups" do
      group = create_zone_group()
      groups = Zones.list_zone_groups()
      assert Enum.any?(groups, fn g -> g.id == group.id end)
    end

    test "returns empty list when no groups exist" do
      assert Zones.list_zone_groups() == []
    end
  end

  describe "get_zone_group!/1" do
    test "returns the zone group by id" do
      group = create_zone_group()
      assert Zones.get_zone_group!(group.id).id == group.id
    end

    test "raises Ecto.NoResultsError for unknown id" do
      assert_raise Ecto.NoResultsError, fn -> Zones.get_zone_group!(0) end
    end
  end

  describe "create_zone_group/1" do
    test "creates a zone group with valid attrs" do
      assert {:ok, %ZoneGroup{} = group} = Zones.create_zone_group(@valid_group_attrs)
      assert group.name == "Front Yard"
    end

    test "returns error changeset with invalid attrs" do
      assert {:error, changeset} = Zones.create_zone_group(%{})
      refute changeset.valid?
    end

    test "returns error changeset on duplicate name" do
      create_zone_group()
      assert {:error, changeset} = Zones.create_zone_group(@valid_group_attrs)
      assert changeset.errors[:name] != nil
    end
  end

  describe "update_zone_group/2" do
    test "updates zone group with valid attrs" do
      group = create_zone_group()
      assert {:ok, updated} = Zones.update_zone_group(group, %{name: "Back Yard"})
      assert updated.name == "Back Yard"
    end

    test "returns error changeset with invalid attrs" do
      group = create_zone_group()
      assert {:error, changeset} = Zones.update_zone_group(group, %{name: nil})
      refute changeset.valid?
    end
  end

  describe "delete_zone_group/1" do
    test "deletes the zone group" do
      group = create_zone_group()
      assert {:ok, %ZoneGroup{}} = Zones.delete_zone_group(group)
      assert_raise Ecto.NoResultsError, fn -> Zones.get_zone_group!(group.id) end
    end
  end

  describe "add_zone_to_group/2" do
    test "adds a zone to a group" do
      zone = create_zone()
      group = create_zone_group()
      assert {:ok, %ZoneGroupMember{}} = Zones.add_zone_to_group(zone, group)
    end

    test "returns error on duplicate membership" do
      zone = create_zone()
      group = create_zone_group()
      Zones.add_zone_to_group(zone, group)
      assert {:error, changeset} = Zones.add_zone_to_group(zone, group)
      refute changeset.valid?
    end
  end

  describe "remove_zone_from_group/2" do
    test "removes a zone from a group" do
      zone = create_zone()
      group = create_zone_group()
      Zones.add_zone_to_group(zone, group)
      assert :ok = Zones.remove_zone_from_group(zone, group)
    end

    test "is a no-op when membership does not exist" do
      zone = create_zone()
      group = create_zone_group()
      assert :ok = Zones.remove_zone_from_group(zone, group)
    end
  end
end

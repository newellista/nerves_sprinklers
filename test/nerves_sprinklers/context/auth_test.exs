defmodule NervesSprinklers.AuthTest do
  use NervesSprinklers.DataCase
  alias NervesSprinklers.Auth

  test "password_set? returns false on fresh DB" do
    refute Auth.password_set?()
  end

  test "set_password and verify_password work" do
    assert :ok = Auth.set_password("mysecretpw")
    assert Auth.password_set?()
    assert Auth.verify_password("mysecretpw")
    refute Auth.verify_password("wrongpassword")
  end

  test "set_password returns error for short password" do
    assert {:error, :too_short} = Auth.set_password("short")
  end
end

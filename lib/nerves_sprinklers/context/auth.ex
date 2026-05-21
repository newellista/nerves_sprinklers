defmodule NervesSprinklers.Auth do
  @moduledoc false

  @iterations 200_000
  @key_length 32

  def password_set? do
    case get_settings() do
      %{password_hash: hash} when is_binary(hash) and byte_size(hash) > 0 -> true
      _ -> false
    end
  end

  def set_password(password) when is_binary(password) and byte_size(password) >= 8 do
    salt = :crypto.strong_rand_bytes(32)
    hash = pbkdf2(password, salt)

    save_settings(%{
      password_hash: Base.encode64(hash),
      password_salt: Base.encode64(salt)
    })
  end

  def set_password(_), do: {:error, :too_short}

  def verify_password(password) do
    case get_settings() do
      %{password_hash: encoded_hash, password_salt: encoded_salt}
      when is_binary(encoded_hash) ->
        hash = Base.decode64!(encoded_hash)
        salt = Base.decode64!(encoded_salt)
        candidate = pbkdf2(password, salt)
        constant_time_compare(candidate, hash)

      _ ->
        false
    end
  end

  defp pbkdf2(password, salt) do
    :crypto.pbkdf2_hmac(:sha256, password, salt, @iterations, @key_length)
  end

  defp constant_time_compare(a, b) when byte_size(a) == byte_size(b) do
    :crypto.hash_equals(a, b)
  end

  defp constant_time_compare(_, _), do: false

  # Settings persistence — Phase 1 will replace this with DB-backed Settings schema.

  defp settings_file do
    Application.get_env(:nerves_sprinklers, :auth_settings_file, "/data/auth_settings.dat")
  end

  defp get_settings do
    case File.read(settings_file()) do
      {:ok, bin} -> :erlang.binary_to_term(bin)
      {:error, _} -> %{}
    end
  end

  defp save_settings(settings) do
    path = settings_file()
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, :erlang.term_to_binary(settings))
    :ok
  end
end

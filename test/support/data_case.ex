defmodule NervesSprinklers.DataCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      alias NervesSprinklers.Repo

      import Ecto
      import Ecto.Query
      import NervesSprinklers.DataCase
    end
  end

  setup tags do
    NervesSprinklers.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(NervesSprinklers.Repo, shared: not tags[:async])

    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end
end

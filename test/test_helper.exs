ExUnit.start()

Ecto.Migrator.run(NervesSprinklers.Repo, :up, all: true)
Ecto.Adapters.SQL.Sandbox.mode(NervesSprinklers.Repo, :manual)

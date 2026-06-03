defmodule NervesSprinklers.History do
  @moduledoc false

  import Ecto.Query

  alias NervesSprinklers.Repo
  alias NervesSprinklers.Schema.ScheduleRun

  def list_schedule_runs(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    ScheduleRun
    |> order_by([r], desc: r.id)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(:zone_runs)
    |> Repo.all()
  end

  def count_schedule_runs do
    Repo.aggregate(ScheduleRun, :count)
  end
end

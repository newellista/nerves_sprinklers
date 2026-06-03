defmodule NervesSprinklers.Scheduler.Scheduler do
  @moduledoc false

  use GenServer
  require Logger

  alias NervesSprinklers.Config.NodeConfig
  alias NervesSprinklers.Executor.Executor
  alias NervesSprinklers.Repo
  alias NervesSprinklers.Scheduler.Recurrence
  alias NervesSprinklers.Schedules

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def reload do
    GenServer.cast(__MODULE__, :reload_all)
  end

  @impl true
  def init(_opts) do
    :erlang.monitor(:time_offset, :clock_service)
    send(self(), :reload_all)
    {:ok, %{timers: %{}}}
  end

  @impl true
  def handle_cast(:reload_all, state) do
    {:noreply, do_reload(state)}
  end

  @impl true
  def handle_info(:reload_all, state) do
    {:noreply, do_reload(state)}
  end

  def handle_info({:schedule_timer_fired, schedule_id}, state) do
    schedule =
      schedule_id
      |> Schedules.get_schedule!()
      |> Repo.preload(schedule_zones: :zone)

    new_timers =
      if schedule.enabled and not paused?(schedule) do
        case Executor.start_run(schedule, :scheduled) do
          :ok ->
            :ok

          {:error, :busy} ->
            Logger.warning("Scheduler: executor busy, skipping schedule #{schedule.id}")
        end

        timezone = NodeConfig.timezone()

        case schedule_timer(schedule, timezone) do
          nil -> Map.delete(state.timers, schedule_id)
          ref -> Map.put(state.timers, schedule_id, ref)
        end
      else
        Map.delete(state.timers, schedule_id)
      end

    {:noreply, %{state | timers: new_timers}}
  end

  def handle_info({:CHANGE, _, :time_offset, :clock_service, _}, state) do
    send(self(), :reload_all)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  defp do_reload(state) do
    Enum.each(state.timers, fn {_id, ref} -> Process.cancel_timer(ref) end)

    timezone = NodeConfig.timezone()
    schedules = Schedules.list_schedules()

    timers =
      schedules
      |> Enum.filter(fn s -> s.enabled and not paused?(s) end)
      |> Enum.reduce(%{}, fn schedule, acc ->
        case schedule_timer(schedule, timezone) do
          nil -> acc
          ref -> Map.put(acc, schedule.id, ref)
        end
      end)

    %{state | timers: timers}
  end

  defp schedule_timer(schedule, timezone) do
    case Recurrence.next_run_after(schedule, DateTime.utc_now(), timezone) do
      nil ->
        nil

      next_dt ->
        ms = max(1000, DateTime.diff(next_dt, DateTime.utc_now(), :millisecond))
        Process.send_after(self(), {:schedule_timer_fired, schedule.id}, ms)
    end
  end

  defp paused?(%{paused_until: nil}), do: false

  defp paused?(%{paused_until: paused_until}),
    do: Date.compare(Date.utc_today(), paused_until) != :gt
end

defmodule NervesSprinklers.Executor.Executor do
  @moduledoc false

  use GenServer
  require Logger

  alias NervesSprinklers.Executor.ZoneDriver
  alias NervesSprinklers.Gpio.GpioServer
  alias NervesSprinklers.Repo
  alias NervesSprinklers.Schema.{ScheduleRun, Zone, ZoneRun}

  @pubsub NervesSprinklers.PubSub
  @topic "executor:status"

  defstruct status: :idle,
            schedule_run_id: nil,
            current_zone: nil,
            zone_seq: 0,
            zone_started_at: nil,
            zone_planned_duration_sec: nil,
            timer_ref: nil,
            queue: []

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_run(schedule, trigger) do
    GenServer.call(__MODULE__, {:start_run, schedule, trigger})
  end

  def abort_run do
    GenServer.call(__MODULE__, :abort_run)
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  def node_went_down(down_node) do
    GenServer.cast(__MODULE__, {:node_went_down, down_node})
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:start_run, _schedule, _trigger}, _from, %{status: :running} = state) do
    {:reply, {:error, :busy}, state}
  end

  def handle_call({:start_run, schedule, trigger}, _from, state) do
    now = DateTime.utc_now()

    schedule_run =
      %ScheduleRun{}
      |> ScheduleRun.changeset(%{
        schedule_id: Map.get(schedule, :id),
        schedule_name: schedule.name,
        trigger_type: trigger,
        started_at: now,
        status: :running
      })
      |> Repo.insert!()

    queue = build_queue(schedule)
    new_state = %{state | status: :running, schedule_run_id: schedule_run.id, queue: queue}
    {:reply, :ok, activate_next_zone(new_state)}
  end

  def handle_call(:abort_run, _from, %{status: :idle} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:abort_run, _from, state) do
    {:reply, :ok, do_abort(state)}
  end

  def handle_call(:get_status, _from, %{status: :idle} = state) do
    {:reply, :idle, state}
  end

  def handle_call(:get_status, _from, state) do
    elapsed = DateTime.diff(DateTime.utc_now(), state.zone_started_at)
    remaining = max(0, state.zone_planned_duration_sec - elapsed)

    {:reply,
     {:running, %{zone: state.current_zone, elapsed_sec: elapsed, remaining_sec: remaining}},
     state}
  end

  @impl true
  def handle_cast({:node_went_down, down_node}, %{status: :running, current_zone: zone} = state)
      when zone != nil do
    if Zone.node_atom(zone) == down_node do
      Logger.warning("Executor: node #{down_node} went down, skipping zone #{zone.name}")
      if state.timer_ref, do: Process.cancel_timer(state.timer_ref)
      elapsed = DateTime.diff(DateTime.utc_now(), state.zone_started_at)

      insert_zone_run(
        state.schedule_run_id,
        zone,
        state.zone_planned_duration_sec,
        elapsed,
        :error
      )

      Phoenix.PubSub.broadcast(@pubsub, @topic, {:zone_completed, zone})
      new_state = %{state | timer_ref: nil, current_zone: nil, zone_started_at: nil}
      {:noreply, activate_next_zone(new_state)}
    else
      {:noreply, state}
    end
  end

  def handle_cast({:node_went_down, _node}, state), do: {:noreply, state}

  @impl true
  def handle_info({:zone_timer_expired, seq}, %{zone_seq: seq} = state) do
    zone = state.current_zone
    ZoneDriver.deactivate(zone)
    elapsed = DateTime.diff(DateTime.utc_now(), state.zone_started_at)

    insert_zone_run(
      state.schedule_run_id,
      zone,
      state.zone_planned_duration_sec,
      elapsed,
      :completed
    )

    Phoenix.PubSub.broadcast(@pubsub, @topic, {:zone_completed, zone})
    new_state = %{state | timer_ref: nil, current_zone: nil, zone_started_at: nil}
    {:noreply, activate_next_zone(new_state)}
  end

  def handle_info({:zone_timer_expired, _stale_seq}, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    if state.current_zone, do: ZoneDriver.deactivate(state.current_zone)
    GpioServer.close_all()
  end

  defp build_queue(schedule) do
    offset = Map.get(schedule, :seasonal_offset, 100)

    schedule.schedule_zones
    |> Enum.sort_by(& &1.position)
    |> Enum.map(fn sz ->
      duration_sec = floor(sz.duration_sec * offset / 100)
      %{zone: sz.zone, duration_sec: duration_sec}
    end)
  end

  defp activate_next_zone(%{queue: []} = state) do
    Repo.get!(ScheduleRun, state.schedule_run_id)
    |> ScheduleRun.changeset(%{status: :completed, completed_at: DateTime.utc_now()})
    |> Repo.update!()

    Phoenix.PubSub.broadcast(@pubsub, @topic, {:run_completed, state.schedule_run_id})
    %{state | status: :idle, schedule_run_id: nil}
  end

  defp activate_next_zone(%{queue: [head | rest]} = state) do
    zone = head.zone
    duration_sec = head.duration_sec

    case ZoneDriver.activate(zone) do
      :ok ->
        Phoenix.PubSub.broadcast(@pubsub, @topic, {:zone_activated, zone})
        seq = state.zone_seq + 1
        timer_ref = Process.send_after(self(), {:zone_timer_expired, seq}, duration_sec * 1000)

        %{
          state
          | queue: rest,
            current_zone: zone,
            zone_seq: seq,
            zone_started_at: DateTime.utc_now(),
            zone_planned_duration_sec: duration_sec,
            timer_ref: timer_ref
        }

      {:error, reason} ->
        Logger.warning("Executor: zone #{zone.name} failed (#{inspect(reason)}), skipping")
        insert_zone_run(state.schedule_run_id, zone, duration_sec, 0, :skipped)
        Phoenix.PubSub.broadcast(@pubsub, @topic, {:zone_completed, zone})
        activate_next_zone(%{state | queue: rest})
    end
  end

  defp do_abort(state) do
    if state.timer_ref, do: Process.cancel_timer(state.timer_ref)

    if state.current_zone do
      ZoneDriver.deactivate(state.current_zone)
      elapsed = DateTime.diff(DateTime.utc_now(), state.zone_started_at)

      insert_zone_run(
        state.schedule_run_id,
        state.current_zone,
        state.zone_planned_duration_sec,
        elapsed,
        :skipped
      )
    end

    Repo.get!(ScheduleRun, state.schedule_run_id)
    |> ScheduleRun.changeset(%{status: :aborted, completed_at: DateTime.utc_now()})
    |> Repo.update!()

    Phoenix.PubSub.broadcast(@pubsub, @topic, {:run_aborted, state.schedule_run_id})

    %{state | status: :idle, schedule_run_id: nil, current_zone: nil, timer_ref: nil, queue: []}
  end

  defp insert_zone_run(schedule_run_id, zone, planned_sec, actual_sec, status) do
    %ZoneRun{}
    |> ZoneRun.changeset(%{
      schedule_run_id: schedule_run_id,
      zone_number: zone.number,
      zone_name: zone.name,
      planned_duration_sec: planned_sec,
      actual_duration_sec: actual_sec,
      status: status
    })
    |> Repo.insert!()
  end
end

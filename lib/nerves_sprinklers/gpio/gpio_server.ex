defmodule NervesSprinklers.Gpio.GpioServer do
  use GenServer
  require Logger

  @pins_file "/data/relay_pins.dat"

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def open_pin(pin), do: GenServer.call(__MODULE__, {:open_pin, pin})
  def close_pin(pin), do: GenServer.call(__MODULE__, {:close_pin, pin})
  def close_all, do: GenServer.call(__MODULE__, :close_all)
  def get_state, do: GenServer.call(__MODULE__, :get_state)
  def add_pin(pin), do: GenServer.call(__MODULE__, {:add_pin, pin})
  def remove_pin(pin), do: GenServer.call(__MODULE__, {:remove_pin, pin})

  # GenServer callbacks

  @impl true
  def init(_opts) do
    pins = load_pins()
    gpio_refs = open_pins_high(pins)
    {:ok, %{pins: pins, gpio_refs: gpio_refs}}
  end

  @impl true
  def handle_call({:open_pin, pin}, _from, state) do
    case Map.fetch(state.gpio_refs, pin) do
      {:ok, ref} ->
        gpio_write(ref, 0)
        {:reply, :ok, state}

      :error ->
        {:reply, {:error, :unknown_pin}, state}
    end
  end

  @impl true
  def handle_call({:close_pin, pin}, _from, state) do
    case Map.fetch(state.gpio_refs, pin) do
      {:ok, ref} ->
        gpio_write(ref, 1)
        {:reply, :ok, state}

      :error ->
        {:reply, {:error, :unknown_pin}, state}
    end
  end

  @impl true
  def handle_call(:close_all, _from, state) do
    Enum.each(state.gpio_refs, fn {_pin, ref} -> gpio_write(ref, 1) end)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    pin_states =
      Map.new(state.gpio_refs, fn {pin, ref} ->
        {pin, gpio_read(ref)}
      end)

    {:reply, pin_states, state}
  end

  @impl true
  def handle_call({:add_pin, pin}, _from, state) do
    if Map.has_key?(state.gpio_refs, pin) do
      {:reply, :ok, state}
    else
      ref = gpio_open(pin)
      new_pins = MapSet.put(state.pins, pin)
      new_refs = Map.put(state.gpio_refs, pin, ref)
      save_pins(new_pins)
      {:reply, :ok, %{state | pins: new_pins, gpio_refs: new_refs}}
    end
  end

  @impl true
  def handle_call({:remove_pin, pin}, _from, state) do
    case Map.fetch(state.gpio_refs, pin) do
      {:ok, ref} ->
        gpio_write(ref, 1)
        gpio_close(ref)
        new_pins = MapSet.delete(state.pins, pin)
        new_refs = Map.delete(state.gpio_refs, pin)
        save_pins(new_pins)
        {:reply, :ok, %{state | pins: new_pins, gpio_refs: new_refs}}

      :error ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.gpio_refs, fn {_pin, ref} ->
      gpio_write(ref, 1)
      gpio_close(ref)
    end)
  end

  # Private helpers

  defp load_pins do
    case File.read(@pins_file) do
      {:ok, bin} ->
        :erlang.binary_to_term(bin)

      {:error, :enoent} ->
        MapSet.new()

      {:error, reason} ->
        Logger.warning("Failed to read relay pins file: #{inspect(reason)}")
        MapSet.new()
    end
  end

  defp save_pins(pins) do
    File.mkdir_p!(Path.dirname(@pins_file))
    File.write!(@pins_file, :erlang.term_to_binary(pins))
  end

  defp open_pins_high(pins) do
    Map.new(pins, fn pin -> {pin, gpio_open(pin)} end)
  end

  # GPIO dispatch — uses circuits_gpio on target, no-op stub on host

  if Mix.target() == :host do
    defp gpio_open(pin) do
      Logger.debug("GPIO mock: open pin #{pin} HIGH")
      {:mock, pin}
    end

    defp gpio_write({:mock, pin}, value) do
      Logger.debug("GPIO mock: pin #{pin} → #{value}")
      :ok
    end

    defp gpio_read({:mock, _pin}), do: 1

    defp gpio_close({:mock, _pin}), do: :ok
  else
    defp gpio_open(pin) do
      {:ok, ref} = Circuits.GPIO.open(pin, :output)
      Circuits.GPIO.write(ref, 1)
      ref
    end

    defp gpio_write(ref, value), do: Circuits.GPIO.write(ref, value)

    defp gpio_read(ref), do: Circuits.GPIO.read(ref)

    defp gpio_close(ref), do: Circuits.GPIO.close(ref)
  end
end

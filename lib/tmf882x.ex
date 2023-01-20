defmodule TMF882X do
  @moduledoc """
  Interface with tmf8820/tmf8821 direct time-of-flight (dToF) sensor ([https://ams.com/en/tmf8820]).

  ### Starting

  Start a `TMF882X` it directly from another process (See Options section below for more info):

  ```elixir
  {:ok, pid} = TMF882X.start_link(bus: "i2c-1")
  ```

  ### Configuration 

  A configuration keyword list can be passed to the `start_link` function containing the following parameters:

  * **`bus`** - Name of the I2C bus that the sensor is attached to.

  * **`interrupt_gpio`** - If the interrupt pin of the sensor is connected, the GPIO number can be specified here.  If not interrupt
                pin is specified, then the library will use I2C to poll when a new measurement packet is ready.

  * **`enable_gpio`** - If the enable pin is connected, the GPIO number can be specified here. If connected, calling `reset/1` will
                use this pin to reset the device.  Otherwise, I2C commands will be issued to reset the device. (default: `nil`)

  * **`auto_start`** - If set to `true`, the device will immediately start taking measurements once the `app_ready` status is `true`.
                    If set to `false`, the device will wait for a call to `start_measuring/1` before taking any measurements. (default: `true`)

  * **`measure_interval`** - Target interval (in milliseconds) between measurements.  If set to `0`, as soon as a measurement is received, another
                          will start.
  * **`device_config`** - The configuration to be sent to the device on startup.  See Configuration section below.

  ### Results

  The calling process will receive messages of the format `{:tmf882x, %TMF882X.Result{}}`:

  ```elixir
  def handle_info({:tmf882x, %TMF882X.Result{} = result}) do
  ...
  end
  ```

  The `TMF882X.Result` struct contains a list of measurements from each channel.  Each measurement is a tuple containing a `distance` (in millimeters) and `confidence` (out of 255) value:

  ```elixir
  %TMF882X.Result{
  tid: 200,
  size: 128,
  number: 200,
  temperature: 41,
  valid_results: 11,
  ambient: 283,
  photon_count: 16971,
  reference_count: 60573,
  sys_tick: 1215866837,
  measurements: [
    {844, 61},
    {841, 106},
    {1010, 56},
    ...
  ]
  }
  ```

  Other fields in the `Result` struct are directly from the decode of the Result register.

  """

  use GenServer
  alias TMF882X.{Device, Bus, Boot, Measure, SPAD}
  require Logger

  @enable_down_time 1

  @type server() :: atom() | pid() | {atom(), any()} | {:via, atom(), any()}

  @doc """
  Starts the measurement process for the given device.  Once started, the process will send 
  `{:tmf882x, %TMF882X.Result{}}` messages each time a measurement is completed.
  """
  @spec start_measuring(server()) :: :ok
  def start_measuring(pid), do: GenServer.cast(pid, :start_measuring)

  @spec measure_once(server()) :: :ok
  def measure_once(pid), do: GenServer.cast(pid, :measure_once)

  @doc """
  Stops the measurement process for the given device.  
  """
  @spec stop_measuring(server()) :: :ok
  def stop_measuring(pid), do: GenServer.cast(pid, :stop_measuring)

  @doc """
  Applies the given configuration values to the device.  This will temporarily stop the 
  measurements and resume them after the configuration if written (if they were running before).
  """
  @spec put_config(server(), map()) :: :ok
  def put_config(pid, config), do: GenServer.cast(pid, {:put_config, config})

  @doc """
  Queries the device for its current configuration and returns it.
  """
  @spec get_config(server()) :: map()
  def get_config(pid), do: GenServer.call(pid, :get_config)

  @doc """
  Queries the device for the current custom spad_map and returns it.
  """
  @spec get_custom_spad(server()) :: map()
  def get_custom_spad(pid), do: GenServer.call(pid, :get_custom_spad)

  @doc """
  Sets the custom spad to the one provided.

  NOTE: the device configuration must be set with `spad_map_id` set to 14
  before the custom spad map can be written. Otherwise, the custom spad
  command will silently fail.
  """
  @spec set_custom_spad(server(), SPAD.t()) :: :ok
  def set_custom_spad(pid, spad), do: GenServer.cast(pid, {:set_custom_spad, spad})

  @doc """
  Resets the device including resetting the enable pin (if configured).
  """
  @spec reset(server()) :: :ok
  def reset(pid), do: GenServer.cast(pid, :reset)

  @doc """
  Returns true if the application on the device has been initialized.  Measurements cannot be started until the 
  `app_ready` flag is `true`.
  """
  @spec app_ready?(server()) :: boolean()
  def app_ready?(pid), do: GenServer.call(pid, :app_ready?)

  def wait_for_app_ready(pid, timeout \\ 1000)
  def wait_for_app_ready(_, timeout) when timeout <= 0, do: {:error, :timout}

  def wait_for_app_ready(pid, timeout) do
    if app_ready?(pid) do
      :ok
    else
      :timer.sleep(10)
      wait_for_app_ready(pid, timeout - 10)
    end
  end

  @doc """
  Returns true if the process is measuring actively.
  """
  @spec running?(server()) :: boolean()
  def running?(pid), do: GenServer.call(pid, :running?)

  @doc """
  Returns the status of the device gathered from the `0xE0` register.
  """
  @spec get_status(server()) :: %{active: boolean(), enabled: boolean()}
  def get_status(pid), do: GenServer.call(pid, :get_status)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(
      TMF882X,
      %{
        bus: Keyword.fetch!(opts, :bus),
        int_gpio: Keyword.get(opts, :interrupt_gpio),
        en_gpio: Keyword.get(opts, :enable_gpio),
        measure_interval: Keyword.get(opts, :measure_interval, 0),
        device_config: Keyword.get(opts, :device_config, %{}),
        auto_start: Keyword.get(opts, :auto_start, true),
        parent: self()
      },
      opts
    )
  end

  @impl true
  def init(config) do
    {:ok, int_gpio} = maybe_open_gpio(config.int_gpio, :input)
    {:ok, en_gpio} = maybe_open_gpio(config.en_gpio, :output)
    if int_gpio, do: :ok = Circuits.GPIO.set_interrupts(int_gpio, :falling)
    {:ok, i2c} = Bus.wait_for_i2c_and_connect(config.bus, 100)

    send(self(), :connect)

    {:ok,
     %{
       device_config: config.device_config,
       int_gpio: int_gpio,
       en_gpio: en_gpio,
       pid: i2c,
       running: false,
       app_ready: false,
       measurement_pending: false,
       parent: config.parent,
       measure_interval: config.measure_interval,
       measure_start: nil,
       auto_start: config.auto_start
     }}
  end

  @impl true
  def handle_call(:app_ready?, _, state), do: {:reply, state.app_ready, state}
  def handle_call(:running?, _, state), do: {:reply, state.running, state}

  def handle_call(:get_config, _, state) do
    if state.measurement_pending do
      :ok = Measure.stop(state.pid)
    end

    config = Device.read_config(state.pid)
    :ok = Measure.enable_interrupt(state.pid)

    if state.running do
      send(self(), :measure)
    end

    {:reply, config, state}
  end

  def handle_call(:get_custom_spad, _, state) do
    if state.measurement_pending do
      :ok = Measure.stop(state.pid)
    end

    spad = Device.get_custom_spad(state.pid)
    :ok = Measure.enable_interrupt(state.pid)

    if state.running do
      send(self(), :measure)
    end

    {:reply, spad, state}
  end

  def handle_call(:get_status, _, state) do
    {:reply, Device.status(state.pid), state}
  end

  def handle_call({:write_read, data, size}, _, state) do
    {:ok, resp} = Bus.write_read(state.pid, data, size)
    {:reply, resp, state}
  end

  @impl true
  def handle_cast(:start_measuring, %{app_ready: true} = state) do
    :ok = Measure.enable_interrupt(state.pid)
    send(self(), :measure)
    {:noreply, %{state | running: true}}
  end

  def handle_cast(:start_measuring, state) do
    {:noreply, state}
  end

  def handle_cast(:stop_measuring, state) do
    :ok = Measure.stop(state.pid)
    {:noreply, %{state | running: false}}
  end

  def handle_cast({:put_config, config}, state) do
    if state.measurement_pending do
      :ok = Measure.stop(state.pid)
    end

    :ok = Device.apply_config(state.pid, config)
    :ok = Measure.enable_interrupt(state.pid)

    if state.running do
      send(self(), :measure)
    end

    {:noreply, state}
  end

  def handle_cast(:reset, state) do
    send(self(), :connect)
    {:noreply, %{state | running: false, app_ready: false}}
  end

  def handle_cast({:write, data}, state) do
    :ok = Bus.write(state.pid, data)
    {:noreply, state}
  end

  def handle_cast({:set_custom_spad, spad}, state) do
    :ok = Device.set_custom_spad(state.pid, spad)
    {:noreply, state}
  end

  def handle_cast(:measure_once, state) do
    :ok = Measure.start(state.pid)
    start = System.monotonic_time()

    if state.int_gpio do
      {:noreply, %{state | measurement_pending: true, measure_start: start}}
    else
      :ok = Measure.wait_for_interrupt(state.pid, 100)
      :ok = complete_measurement(%{state | measure_start: start}, false)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:connect, state) do
    with :ok <- reset_enable_pin(state.en_gpio),
         :ok <- Bus.wait_for_device(state.pid, 100),
         :ok <- Device.enable(state.pid),
         :ok <- Device.wait_for_enabled(state.pid, 100),
         :ok <- Boot.load_app_if_in_bootloader(state.pid),
         :ok <- Device.apply_config(state.pid, state.device_config),
         :ok <- Measure.enable_interrupt(state.pid) do
      if state.auto_start do
        send(self(), :measure)
      end

      {:noreply, %{state | running: state.auto_start, app_ready: true}}
    end
  end

  def handle_info(:measure, %{running: true} = state) do
    :ok = Measure.start(state.pid)
    start = System.monotonic_time()

    if state.int_gpio do
      {:noreply, %{state | measurement_pending: true, measure_start: start}}
    else
      :ok = Measure.wait_for_interrupt(state.pid, 100)
      :ok = complete_measurement(%{state | measure_start: start})
      {:noreply, state}
    end
  end

  def handle_info(:measure, state), do: {:noreply, state}

  def handle_info({:circuits_gpio, _, _, 0}, %{measurement_pending: true} = state) do
    :ok = complete_measurement(state)
    {:noreply, %{state | measurement_pending: false}}
  end

  def handle_info({:circuits_gpio, _, _, _}, state), do: {:noreply, state}

  defp reset_enable_pin(nil), do: :ok

  defp reset_enable_pin(en_gpio) do
    :ok = Circuits.GPIO.write(en_gpio, 0)
    :timer.sleep(@enable_down_time)
    Circuits.GPIO.write(en_gpio, 1)
  end

  def calc_measure_delay(state) do
    time =
      (System.monotonic_time() - state.measure_start)
      |> System.convert_time_unit(:native, :millisecond)

    (state.measure_interval - time) |> max(0)
  end

  defp maybe_open_gpio(nil, _), do: {:ok, nil}
  defp maybe_open_gpio(pin, mode), do: Circuits.GPIO.open(pin, mode)

  defp complete_measurement(state, repeat \\ true) do
    result = Measure.read_data(state.pid)
    send(state.parent, {:tmf882x, result})
    if repeat, do: :timer.send_after(calc_measure_delay(state), :measure)
    Measure.clear_interrupts(state.pid)
  end
end

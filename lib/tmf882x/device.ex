defmodule TMF882X.Device do
  @moduledoc """
  Handles communication around device setup and configuration.
  """
  alias TMF882X.{Bus, Config, SPAD}
  require Logger

  @wait_time 1
  @enable_wait 1
  @stat_ok_wait 1

  @doc """
  Enables the device via I2C when the enable pin is not connected.
  """
  @spec enable(reference()) :: :ok | {:error, any()}
  def enable(pid) do
    Bus.write(pid, <<0xE0, 0x01>>)
  end

  @doc """
  Waits until the status of the device returns as enabled.  Ether returns :ok if the device becomes enabled or
  {:ok, :enable_timeout} if the device is not enabled before the timeout.
  """
  @spec wait_for_enabled(reference(), non_neg_integer()) :: :ok | {:error, :enable_timeout}
  def wait_for_enabled(i2c, timeout) when timeout > 0 do
    if status(i2c).enabled do
      :ok
    else
      :timer.sleep(@enable_wait)
      wait_for_enabled(i2c, timeout - @enable_wait)
    end
  end

  def wait_for_enabled(_, _), do: {:error, :enable_timeout}

  @doc """
  Waits until the STAT_OK register returns a value less than `0x10` and returns `:ok` or returns {:error, :wait_timeout} if it
  does not before the given timeout (in ms).
  """
  @spec wait(reference(), non_neg_integer()) :: :ok | {:error, :wait_timeout}
  def wait(pid, remain) when remain > 0 do
    :timer.sleep(@wait_time)

    Bus.write_read(pid, <<0x08>>, 1)
    |> case do
      {:ok, <<a>>} when a < 0x10 -> :ok
      {:ok, _} -> wait(pid, remain - @wait_time)
    end
  end

  def wait(_, _), do: {:error, :wait_timeout}

  @doc """
  Waits until the STAT_OK register returns a value of `0x00` and returns :ok or returns {:error, :wait_timeout} if it
  does not before the given timeout (in ms).
  """
  @spec wait_for_stat_ok(reference(), non_neg_integer()) :: :ok | {:error, :wait_timeout}
  def wait_for_stat_ok(pid, remain) when remain > 0 do
    :timer.sleep(@stat_ok_wait)

    Bus.write_read(pid, <<0x08>>, 1)
    |> case do
      {:ok, <<0x00>>} -> :ok
      {:ok, _} -> wait_for_stat_ok(pid, remain - @stat_ok_wait)
    end
  end

  def wait_for_stat_ok(_, _), do: {:error, :wait_timeout}

  @doc """
  Returns firmware information for the device.
  """
  @spec firmware(reference()) :: %{app_id: byte(), major: byte(), minor: byte()}
  def firmware(pid) do
    {:ok, <<app_id, major, minor>>} = Bus.write_read(pid, <<0x00>>, 3)
    %{app_id: app_id, major: major, minor: minor}
  end

  @doc """
  Returns the status of the device gathered from the `0xE0` register
  """
  @spec status(reference()) :: %{
          active: boolean(),
          enabled: boolean(),
          set_bits: <<_::2>>,
          status: byte()
        }
  def status(pid) do
    {:ok, <<_::size(1), active::size(1), set_bits::size(2), status::size(4)>>} =
      Bus.write_read(pid, <<0xE0>>, 1)

    %{
      active: active == 1,
      set_bits: <<set_bits::size(2)>>,
      status: status,
      enabled: status == 0b0001
    }
  end

  @doc """
  Read the contents of the configuration page register and returns them as a `TMF882X.Config` struct.
  """
  def read_config(pid) do
    :ok = enter_config_mode(pid)
    {:ok, data} = Bus.write_read(pid, <<0x20>>, 31)
    data |> Config.new()
  end

  defp enter_config_mode(pid) do
    :ok = Bus.write(pid, <<0x08, 0x16>>)
    wait(pid, 500)

    case Bus.write_read(pid, <<0x20>>, 4) do
      {:ok, <<0x16, _, 0xBC, 0x00>>} -> :ok
      _ -> :error
    end
  end

  @doc """
  Applies a subset of configuration
  """
  @spec apply_config(reference(), map()) :: :ok | :error
  def apply_config(pid, config) do
    commands =
      config
      |> Enum.map(fn {key, value} ->
        case key do
          :period -> Config.cmd_period(value)
          :spad_map_id -> Config.cmd_spad_map_id(value)
          _ -> Logger.warning("[#{__MODULE__}] Unsupported config option: #{inspect(key)}")
        end
      end)
      |> Enum.filter(&is_binary/1)

    :ok = enter_config_mode(pid)

    commands
    |> Enum.each(fn cmd ->
      Bus.write(pid, cmd)
    end)

    write_config(pid)
  end

  defp write_config(pid) do
    :ok = Bus.write(pid, <<0x08, 0x15>>)
    wait(pid, 500)
  end

  @doc """
  Sets the spad in the custom spad page to the provided one.
  """
  @spec set_custom_spad(reference(), SPAD.t()) :: :ok | :error
  def set_custom_spad(pid, spad) do
    :ok = enter_spad_mode(pid)
    data = SPAD.encode(spad)
    :ok = Bus.write(pid, <<0x24>> <> data)
    write_config(pid)
  end

  @doc """
  Returns the SPAD currently in the custom page.
  """
  @spec get_custom_spad(reference()) :: SPAD.t()
  def get_custom_spad(pid) do
    :ok = enter_spad_mode(pid)
    {:ok, data} = Bus.write_read(pid, <<0x20>>, 132)
    data |> SPAD.decode()
  end

  defp enter_spad_mode(pid) do
    :ok = Bus.write(pid, <<0x08, 0x17>>)
    :ok = wait(pid, 500)

    case Bus.write_read(pid, <<0x20>>, 1) do
      {:ok, <<0x17>>} ->
        :ok

      e ->
        Logger.error("[#{__MODULE__}] Error: #{inspect(e)}")
        :error
    end
  end
end

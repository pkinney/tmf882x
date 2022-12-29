defmodule TMF882X.Bus do
  @moduledoc """
  Module for interfacing with the TMF882X over I2C. This module handles the lower-level communication with the device.
  """
  alias Circuits.I2C
  require Logger

  @address 0x41
  @log_messages false
  @log_errors true
  @i2c_wait 10

  @doc """
  Waits for the i2c bus to become available and connects to it.  Returns {:ok, pid} when successful or
  `{:error, :i2c_timeout}` if not bus connection was made before the given timeout
  """
  @spec wait_for_i2c_and_connect(String.t(), non_neg_integer) ::
          {:ok, reference()} | {:error, :i2c_timeout}
  def wait_for_i2c_and_connect(bus, timeout) when timeout > 0 do
    case I2C.open(bus) do
      {:ok, pid} ->
        Logger.info("[#{__MODULE__}] Connected to i2c bus `#{bus}`")
        {:ok, pid}

      e ->
        Logger.warn("[#{__MODULE__}] Could not connect to bus `#{bus}`: #{inspect(e)}")
        :timer.sleep(@i2c_wait)
        wait_for_i2c_and_connect(bus, timeout - @i2c_wait)
    end
  end

  def wait_for_i2c_and_connect(_, _), do: {:error, :i2c_timeout}

  @doc """
  Waits for  the device to be present on the I2C bus and returns :ok when it is found, or `{:error, :i2c_device_timeout}`
  if the device is not found before the given timeout (in ms).
  """
  @spec wait_for_device(reference(), non_neg_integer) :: :ok | {:error, :i2c_device_timeout}
  def wait_for_device(i2c, timeout) when timeout > 0 do
    if I2C.device_present?(i2c, @address) do
      Logger.info("[#{__MODULE__}] Device 0x#{@address |> Integer.to_string(16)} found")
      :ok
    else
      Logger.warn("[#{__MODULE__}] Could not find device on i2c bus")
      :timer.sleep(@i2c_wait)
      wait_for_device(i2c, timeout - @i2c_wait)
    end
  end

  def wait_for_device(_, _), do: {:error, :i2c_device_timeout}

  @doc """
  Writes data to the bus.
  """
  @spec write(reference(), binary()) :: :ok | {:error, any}
  def write(pid, data) do
    I2C.write(pid, @address, data) |> debug_write(data)
  end

  @doc """
  Reads a number of bytes from the bus
  """
  @spec read(reference(), non_neg_integer()) :: {:ok, binary()} | {:error, any}
  def read(pid, size) do
    I2C.read(pid, @address, size) |> debug_read(size)
  end

  @doc """
  Writes the given data to the bus then immediately reads the given number of bytes off of the bus.
  """
  @spec write_read(reference(), binary(), non_neg_integer()) :: {:ok, binary} | {:error, any}
  def write_read(pid, data, size) do
    I2C.write_read(pid, @address, data, size) |> debug_write_read(data, size)
  end

  defp debug_write(result, data) do
    debug("Write: #{inspect(data, base: :hex)} -> #{inspect(result, base: :hex)}")
    result
  end

  defp debug_read({:ok, resp}, size) do
    debug(" Read #{size} bytes: #{inspect(resp, base: :hex)}")
    {:ok, resp}
  end

  defp debug_read(err, size) do
    error("Read #{size} bytes: error: #{inspect(err, base: :hex)}")
    err
  end

  defp debug_write_read({:ok, resp}, data, size) do
    debug("Write #{inspect(data, base: :hex)}, read #{size} bytes: #{inspect(resp, base: :hex)}")
    {:ok, resp}
  end

  defp debug_write_read(err, data, size) do
    error(
      "Write #{inspect(data, base: :hex)}, read #{size} bytes: error: #{inspect(err, base: :hex)}"
    )

    err
  end

  if @log_messages do
    defp debug(str) do
      Logger.info("[#{__MODULE__}] " <> str)
    end
  else
    defp debug(_), do: :ok
  end

  if @log_errors do
    defp error(str) do
      Logger.error("[#{__MODULE__}] " <> str)
    end
  else
    defp error(_), :ok
  end
end

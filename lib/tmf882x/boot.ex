defmodule TMF882X.Boot do
  @moduledoc """
  Module for managing the bootloader interaction.  Each time the TMF882X is started, the measurement application must be written
  to its memory.  The actual application is encoded in `TMF882X.Firmware.image/0)`.
  """
  alias TMF882X.{Bus, Device, Firmware}
  import Bitwise

  @firmware_chunk_size 128
  @firmware_write_wait 500
  @app_ready_wait_time 1

  @doc """
  Checks to see if the device is currently running the bootloader and, if so, writes the measurement application to
  firmware and starts it.
  """
  def load_app_if_in_bootloader(pid) do
    case Device.firmware(pid) do
      %{app_id: 0x80} -> load_app(pid)
      %{app_id: 0x03} -> :ok
    end
  end

  @doc """
  Loads the app from `TMF882X.Firmware.image/0` onto the device and starts it.
  """
  @spec load_app(reference()) :: :ok
  def load_app(pid) do
    :ok = download_init(pid)
    :ok = Device.wait_for_stat_ok(pid, 500)
    :ok = set_address(pid, <<0x00, 0x00>>)
    :ok = Device.wait_for_stat_ok(pid, 500)
    :ok = load_app(pid, Firmware.image())
    :ok = ram_remap(pid)
    wait_for_measurement_app(pid, 3)
  end

  defp download_init(pid) do
    Bus.write(pid, <<0x08, 0x14, 0x01, 0x29>> |> add_checksum())
  end

  defp set_address(pid, address) do
    Bus.write(pid, (<<0x08, 0x43, 0x02>> <> address) |> add_checksum())
  end

  defp load_app(pid, <<chunk::binary-size(@firmware_chunk_size)>> <> rest) do
    :ok = Bus.write(pid, (<<0x08, 0x41, @firmware_chunk_size>> <> chunk) |> add_checksum())

    :ok = Device.wait_for_stat_ok(pid, @firmware_write_wait)
    load_app(pid, rest)
  end

  defp load_app(pid, chunk) do
    :ok = Bus.write(pid, (<<0x08, 0x41, byte_size(chunk)>> <> chunk) |> add_checksum())

    Device.wait_for_stat_ok(pid, @firmware_write_wait)
  end

  defp ram_remap(pid) do
    :ok = Bus.write(pid, <<0x08, 0x11, 0x00>> |> add_checksum())
  end

  defp wait_for_measurement_app(pid, remain) when remain > 0 do
    :timer.sleep(@app_ready_wait_time)

    TMF882X.Device.firmware(pid)
    |> case do
      %{app_id: 0x03} -> :ok
      _ -> wait_for_measurement_app(pid, remain - @app_ready_wait_time)
    end
  end

  defp wait_for_measurement_app(_, _), do: {:error, :measurement_app_timed_out}

  defp add_checksum(<<cmd, cmd_stat, size>> <> data) do
    sum = calc_data_sum(data)
    chk = bxor(cmd_stat + size + sum, 0xFF)
    <<cmd, cmd_stat, size>> <> data <> <<chk>>
  end

  defp calc_data_sum(""), do: 0

  defp calc_data_sum(<<a>> <> rest) do
    a + calc_data_sum(rest)
  end
end

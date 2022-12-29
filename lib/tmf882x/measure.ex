defmodule TMF882X.Measure do
  @moduledoc """
  Manages the starting and stopping of the measurement process.
  """
  alias TMF882X.{Bus, Device, Result, Util}

  @interrupt_wait 1

  @doc """
  Enables the interrupt register
  """
  @spec enable_interrupt(reference()) :: :ok | {:error, any}
  def enable_interrupt(pid) do
    Bus.write(pid, <<0xE2, 0x02>>)
    :timer.sleep(1)
    clear_interrupts(pid)
  end

  @doc """
  Waits for interrupt bit to be set.  Useful when the interrupt pin is not used.
  """
  def wait_for_interrupt(pid, timeout) do
    if interrupt?(pid) do
      :ok
    else
      :timer.sleep(@interrupt_wait)
      wait_for_interrupt(pid, timeout - @interrupt_wait)
    end
  end

  defp interrupt?(pid) do
    {:ok, <<a>>} = Bus.write_read(pid, <<0xE1>>, 1)
    Util.bit_set?(a, 1)
  end

  @doc """
  Clears the interrupt register
  """
  def clear_interrupts(pid) do
    Bus.write(pid, <<0xE1, 0xFF>>)
  end

  @doc """
  Starts a measurement
  """
  def start(pid) do
    Bus.write(pid, <<0x08, 0x10>>)
  end

  @doc """
  Stops a measurement in progress
  """
  def stop(pid) do
    :ok = Bus.write(pid, <<0x08, 0xFF>>)
    Device.wait_for_stat_ok(pid, 100)
  end

  @doc """
  Reads the data in the measurement registry and returns the decoded `TMF882X.Result` struct.
  """
  def read_data(pid) do
    {:ok, data} = Bus.write_read(pid, <<0x20>>, 132)
    Result.new(data)
  end
end

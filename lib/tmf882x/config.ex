defmodule TMF882X.Config do
  @moduledoc """
  Handles translation to and from configuration registers.
  """
  @type gpio_config() :: %{
          driver_strength: non_neg_integer(),
          pre_delay: non_neg_integer(),
          gpio: non_neg_integer()
        }

  @type power_cfg() :: %{
          goto_standby_timed: boolean(),
          low_power_osc_on: boolean(),
          keep_pll_running: boolean(),
          allow_osc_retrim: boolean(),
          pulse_interrupt: boolean()
        }
  @type alg_setting() :: %{
          logarithmic_confidence: boolean(),
          distances: boolean()
        }
  @type t() :: %{
          period: non_neg_integer(),
          kilo_iterations: non_neg_integer(),
          int_threshold_low: non_neg_integer(),
          int_threshold_high: non_neg_integer(),
          int_zone_mask_0: non_neg_integer(),
          int_zone_mask_1: non_neg_integer(),
          int_zone_mask_2: non_neg_integer(),
          int_persistence: non_neg_integer(),
          confidence_threshold: non_neg_integer(),
          gpio_1: gpio_config(),
          gpio_2: gpio_config(),
          power_cfg: power_cfg(),
          spad_map_id: non_neg_integer(),
          alg_setting_0: alg_setting(),
          hist_dump: boolean(),
          i2c_slave_address: non_neg_integer(),
          osc_trim_value: non_neg_integer(),
          i2c_addr_change: non_neg_integer()
        }

  import Bitwise
  import TMF882X.Util

  @doc """
  Creates a new Config from the config register page.  The expected registers start at the `<<0x16>>` expected in register `0x20`.
  """
  @spec new(binary()) :: t()
  def new(<<0x16, _::bits>> = data) do
    %{
      period: extract_int_2_at(data, 0x24, 0x20),
      kilo_iterations: extract_int_2_at(data, 0x26, 0x20),
      int_threshold_low: extract_int_2_at(data, 0x28, 0x20),
      int_threshold_high: extract_int_2_at(data, 0x2A, 0x20),
      int_zone_mask_0: extract_int_1_at(data, 0x2C, 0x20),
      int_zone_mask_1: extract_int_1_at(data, 0x2D, 0x20),
      int_zone_mask_2: extract_int_1_at(data, 0x2E, 0x20),
      int_persistence: extract_int_1_at(data, 0x2F, 0x20),
      confidence_threshold: extract_int_1_at(data, 0x30, 0x20),
      gpio_1: extract_gpio(data, 0x31, 0x20),
      gpio_2: extract_gpio(data, 0x32, 0x20),
      power_cfg: extract_power_cfg(data, 0x33, 0x20),
      spad_map_id: extract_int_1_at(data, 0x34, 0x20),
      alg_setting_0: extract_alg_setting_0(data, 0x35, 0x20),
      hist_dump: extract_int_1_at(data, 0x39, 0x20) |> bit_set?(0),
      i2c_slave_address: extract_int_1_at(data, 0x3B, 0x20) >>> 1,
      osc_trim_value: extract_int_2_at(data, 0x3C, 0x20),
      i2c_addr_change: extract_int_1_at(data, 0x3E, 0x20)
    }
  end

  defp extract_gpio(data, address, base) do
    a = extract_int_1_at(data, address, base)
    <<driver_strength::size(2), _::size(1), pre_delay::size(2), gpio::size(3)>> = <<a>>
    %{driver_strength: driver_strength, pre_delay: pre_delay, gpio: gpio}
  end

  defp extract_power_cfg(data, address, base) do
    a = extract_int_1_at(data, address, base)

    %{
      goto_standby_timed: bit_set?(a, 7),
      low_power_osc_on: bit_set?(a, 6),
      keep_pll_running: bit_set?(a, 5),
      allow_osc_retrim: bit_set?(a, 3),
      pulse_interrupt: bit_set?(a, 2)
    }
  end

  defp extract_alg_setting_0(data, address, base) do
    a = extract_int_1_at(data, address, base)

    %{
      logarithmic_confidence: bit_set?(a, 7),
      distances: bit_set?(a, 2)
    }
  end

  @doc """
  Creates a command to set the measurement period
  """
  @spec cmd_period(non_neg_integer()) :: binary()
  def cmd_period(period) do
    <<0x24>> <> encode_int_2(period)
  end

  @doc """
  Creates a command to set the spad_map_id
  """
  @spec cmd_spad_map_id(non_neg_integer()) :: binary()
  def cmd_spad_map_id(map_id) do
    <<0x34, map_id>>
  end
end

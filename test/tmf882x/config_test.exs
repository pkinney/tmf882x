defmodule TMF882X.ConfigTest do
  use ExUnit.Case
  alias TMF882X.Config

  test "parse a configuration" do
    config =
      <<22, 152, 188, 0, 33, 0, 25, 2, 0, 0, 255, 255, 0, 0, 0, 0, 6, 0, 0, 0, 1, 4, 0, 0, 0, 0,
        0, 130, 252, 1, 0>>
      |> Config.new()

    assert config.period == 33
    assert config.kilo_iterations == 537
    assert config.int_threshold_low == 0
    assert config.int_threshold_high == 0xFFFF
    assert config.int_zone_mask_0 == 0x00
    assert config.int_zone_mask_1 == 0x00
    assert config.int_zone_mask_2 == 0x00
    assert config.int_persistence == 0x00
    assert config.confidence_threshold == 6
    assert config.gpio_1 == %{driver_strength: 0, gpio: 0, pre_delay: 0}
    assert config.gpio_2 == %{driver_strength: 0, gpio: 0, pre_delay: 0}

    assert config.power_cfg == %{
             allow_osc_retrim: false,
             goto_standby_timed: false,
             keep_pll_running: false,
             low_power_osc_on: false,
             pulse_interrupt: false
           }

    assert config.spad_map_id == 1
    assert config.alg_setting_0 == %{distances: true, logarithmic_confidence: false}
    assert config.hist_dump == false
    assert config.i2c_slave_address == 0x41
    assert config.osc_trim_value == 508
    assert config.i2c_addr_change == 0x00
  end
end

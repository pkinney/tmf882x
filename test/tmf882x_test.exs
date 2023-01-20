defmodule TMF882XTest do
  use ExUnit.Case

  # The startup Replay sequence that already has the app flashed
  defp startup_steps() do
    [
      {:write, 0x41, <<0xE0, 0x01>>},
      {:write_read, 0x41, <<0xE0>>, <<0x41>>},
      {:write_read, 0x41, <<0x0>>, <<0x03, 0, 0>>},
      {:write, 0x41, <<0x08, 0x16>>},
      {:write_read, 0x41, <<0x8>>, <<0x0>>},
      {:write_read, 0x41, <<0x20>>, <<0x16, 0x00, 0xBC, 0x00>>},
      {:write, 0x41, <<0x08, 0x15>>},
      {:write_read, 0x41, <<0x8>>, <<0x0>>},
      {:write, 0x41, <<0xE2, 0x02>>},
      {:write, 0x41, <<0xE1, 0xFF>>}
    ]
  end

  test "startup without needing to flash app" do
    replay = Replay.replay_i2c(startup_steps())

    {:ok, pid} = TMF882X.start_link(bus: "i2c-1", auto_start: false)
    TMF882X.wait_for_app_ready(pid)
    Replay.await_complete(replay)
  end

  test "take a single measurement" do
    replay =
      Replay.replay_i2c(
        startup_steps() ++
          [
            {:write, 0x41, <<0x8, 0x10>>},
            {:write_read, 0x41, <<0xE1>>, <<0x00>>},
            {:write_read, 0x41, <<0xE1>>, <<0x03>>},
            {:write_read, 0x41, <<0x20>>,
             <<0x10, 0xC8, 0x80, 0x0, 0xC8, 0x29, 0xB, 0x0, 0x1B, 0x1, 0x0, 0x0, 0x4B, 0x42, 0x0,
               0x0, 0x9D, 0xEC, 0x0, 0x0, 0xD5, 0xA7, 0x78, 0x48, 0x3D, 0x4C, 0x3, 0x6A, 0x49,
               0x3, 0x38, 0xF2, 0x3, 0xFF, 0xA6, 0x3, 0xFF, 0x3C, 0x4, 0x41, 0x65, 0x5, 0xFF,
               0x37, 0x3, 0xFF, 0xB2, 0x3, 0x5E, 0x8D, 0x4, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
               0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
               0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
               0x0, 0x0, 0x0, 0x49, 0xC, 0x6, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x14, 0x37, 0x8, 0x0,
               0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
               0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0>>},
            {:write, 0x41, <<0xE1, 0xFF>>}
          ]
      )

    {:ok, pid} = TMF882X.start_link(bus: "i2c-1", auto_start: false)
    TMF882X.wait_for_app_ready(pid)
    TMF882X.measure_once(pid)
    assert_receive {:tmf882x, %TMF882X.Result{} = result}
    assert result.photon_count == 16_971
    Replay.await_complete(replay)
  end

  test "receive a measurement using a GPIO interrupt" do
    replay =
      Replay.replay_i2c(
        startup_steps() ++
          [
            {:write, 0x41, <<0x8, 0x10>>},
            {:write_read, 0x41, <<0x20>>,
             <<0x10, 0xC8, 0x80, 0x0, 0xC8, 0x29, 0xB, 0x0, 0x1B, 0x1, 0x0, 0x0, 0x4B, 0x42, 0x0,
               0x0, 0x9D, 0xEC, 0x0, 0x0, 0xD5, 0xA7, 0x78, 0x48, 0x3D, 0x4C, 0x3, 0x6A, 0x49,
               0x3, 0x38, 0xF2, 0x3, 0xFF, 0xA6, 0x3, 0xFF, 0x3C, 0x4, 0x41, 0x65, 0x5, 0xFF,
               0x37, 0x3, 0xFF, 0xB2, 0x3, 0x5E, 0x8D, 0x4, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
               0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
               0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
               0x0, 0x0, 0x0, 0x49, 0xC, 0x6, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x14, 0x37, 0x8, 0x0,
               0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,
               0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0>>},
            {:write, 0x41, <<0xE1, 0xFF>>}
          ]
      )

    # We use a "fake" gpio pin so that we can cause the interrupt to happen after we star reading
    Replay.replay_gpio([{:write, 1, 1}, {:interrupt, 18, 0}])

    {:ok, pid} = TMF882X.start_link(bus: "i2c-1", interrupt_gpio: 18, auto_start: false)
    TMF882X.wait_for_app_ready(pid)
    TMF882X.measure_once(pid)

    {:ok, fake_gpio} = Circuits.GPIO.open(1, :output)
    :ok = Circuits.GPIO.write(fake_gpio, 1)

    assert_receive {:tmf882x, %TMF882X.Result{} = result}

    assert result.photon_count == 16_971
    Replay.await_complete(replay)
  end
end

defmodule TMF882X.ResultTest do
  use ExUnit.Case

  alias TMF882X.Result

  test "decode a data chunk" do
    {:ok, data} =
      "EMiAAMgpCwAbAQAAS0IAAJ3sAADVp3hIPUwDakkDOPID/6YD/zwEQWUF/zcD/7IDXo0EAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAASQwGAAAAAAAAFDcIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
      |> Base.decode64()

    result = Result.new(data)
    assert result.tid == 200
    assert result.size == 128
    assert result.number == 200
    assert result.temperature == 41
    assert result.valid_results == 11
    assert result.ambient == 283
    assert result.photon_count == 16_971
    assert result.reference_count == 60_573
    assert result.sys_tick == 1_215_866_837
    assert length(result.measurements) == 36
    assert List.first(result.measurements) == {844, 61}
  end
end

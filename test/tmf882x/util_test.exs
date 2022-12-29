defmodule TMF882X.UtilTest do
  use ExUnit.Case
  alias TMF882X.Util

  test "bit_set?" do
    assert Util.bit_set?(8, 3)
    assert Util.bit_set?(<<0x20>>, 5)
    assert Util.bit_set?(128, 7)

    refute Util.bit_set?(128, 6)
    refute Util.bit_set?(254, 0)
  end

  test "encode_int_1" do
    assert 0xAD |> Util.encode_int_1() |> Util.extract_int_1() == 0xAD
  end

  test "encode_int_2" do
    assert 0xABCD |> Util.encode_int_2() |> Util.extract_int_2() == 0xABCD
  end

  test "encode_int_4" do
    assert 0xABCDE987 |> Util.encode_int_4() |> Util.extract_int_4() == 0xABCDE987
  end
end

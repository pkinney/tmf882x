defmodule TMF882X.SPADTest do
  use ExUnit.Case

  alias TMF882X.SPAD

  test "decode a known spad config" do
    data =
      "F7u8AP8/AP8/AP8/AP8/AP8/AP8/AAAAAAAAAAAAAAAAADMM8AAzDPAAMwzwADMM8AAzDPAADMDAAAzAwAAMwMAADMDAADPwwAAz8MAAM/DAADPwwAAz8MAAAAAAAAAAAAAAAAAAAAAAAAMAAAAADgYACAABAAAAAAAAAAAAAAAAAAAA"
      |> Base.decode64!()

    spad = data |> SPAD.decode()

    assert spad.x_offset == 0
    assert spad.y_offset == 0
    assert spad.x_size == 14
    assert spad.y_size == 6

    assert spad.mask ==
             [
               [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
               [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
               [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
               [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
               [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
               [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
               [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
               [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
               [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
               [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
             ]

    assert spad.map ==
             [
               [1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 0, 0, 0, 0],
               [1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 0, 0, 0, 0],
               [4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6, 0, 0, 0, 0],
               [4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6, 0, 0, 0, 0],
               [7, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 9, 9, 0, 0, 0, 0],
               [7, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 9, 9, 0, 0, 0, 0],
               [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
               [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
               [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
               [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
             ]
  end

  test "encode and decode a spad" do
    data =
      "F7u8AP8/AP8/AP8/AP8/AP8/AP8/AAAAAAAAAAAAAAAAADMM8AAzDPAAMwzwADMM8AAzDPAADMDAAAzAwAAMwMAADMDAADPwwAAz8MAAM/DAADPwwAAz8MAAAAAAAAAAAAAAAAAAAAAAAAMAAAAADgYACAABAAAAAAAAAAAAAAAAAAAA"
      |> Base.decode64!()

    spad = data |> SPAD.decode()
    encoded = spad |> SPAD.encode()

    assert (<<0x17, 0xBB, 0xBC, 0x00>> <>
              encoded)
           |> SPAD.decode() == spad
  end

  test "encode a spad config" do
    spad = %{
      x_offset: 0,
      y_offset: 0,
      x_size: 14,
      y_size: 6,
      mask: [
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
        [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      ],
      map: [
        [1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 0, 0, 0, 0],
        [1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 0, 0, 0, 0],
        [4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6, 0, 0, 0, 0],
        [4, 4, 4, 4, 4, 5, 5, 5, 5, 6, 6, 6, 6, 6, 0, 0, 0, 0],
        [7, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 9, 9, 0, 0, 0, 0],
        [7, 7, 7, 7, 7, 8, 8, 8, 8, 9, 9, 9, 9, 9, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      ]
    }

    data =
      "F7u8AP8/AP8/AP8/AP8/AP8/AP8/AAAAAAAAAAAAAAAAADMM8AAzDPAAMwzwADMM8AAzDPAADMDAAAzAwAAMwMAADMDAADPwwAAz8MAAM/DAADPwwAAz8MAAAAAAAAAAAAAAAAAAAAAAAAMAAAAADgY="
      |> Base.decode64!()

    assert <<0x17, 0xBB, 0xBC, 0x00>> <> (spad |> SPAD.encode()) == data
  end
end

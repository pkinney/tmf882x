defmodule TMF882X.SPAD do
  @moduledoc false
  @type t() :: %{
          x_offset: non_neg_integer(),
          y_offset: non_neg_integer(),
          x_size: non_neg_integer(),
          y_size: non_neg_integer(),
          mask: list(list(non_neg_integer())),
          map: list(list(non_neg_integer()))
        }

  import Bitwise
  alias TMF882X.Util
  require Logger

  @doc """
  Creates a new SPAD map from the SPAD register page contents.  The expected registers start at the `<<0x17>>` expected in register `0x20`.
  """
  @spec decode(binary()) :: t()
  def decode(data) do
    x_size = Util.extract_int_1_at(data, 0x8F, 0x20)
    y_size = Util.extract_int_1_at(data, 0x90, 0x20)

    mask =
      Util.extract_multi_int_3(data, 0x24, 0x20, y_size)
      |> Enum.map(fn row ->
        0..(x_size - 1)
        |> Enum.map(fn x ->
          if Util.bit_set?(row, x), do: 1, else: 0
        end)
        |> pad(18 - x_size, 0)
      end)
      |> pad(10 - y_size, for(_ <- 1..18, do: 0))

    map_rows = Util.extract_multi_int_4(data, 0x42, 0x20, x_size)
    ch_select = Util.extract_int_3_at(data, 0x8A, 0x20)

    map =
      map_rows
      |> Enum.map(fn row ->
        0..(y_size - 1)
        |> Enum.reverse()
        |> Enum.map(fn y ->
          decode_channel(row, y, ch_select)
        end)
        |> pad(10 - y_size, 0)
      end)
      |> transpose()
      |> Enum.map(&pad(&1, 18 - x_size, 0))

    %{
      x_offset: Util.extract_int_1_at(data, 0x8D, 0x20),
      y_offset: Util.extract_int_1_at(data, 0x8E, 0x20),
      x_size: x_size,
      y_size: y_size,
      mask: mask,
      map: map
    }
  end

  @doc """
  Encodes a SPAD map into the format for writing to the register.  Note that this does not contain the first
  4 bytes of the register and can be written starting at address `0x24`.
  """
  @spec encode(t()) :: binary()
  def encode(spad) do
    mask = Enum.flat_map(spad.mask, fn row -> encode_mask_row(row) end) |> :binary.list_to_bin()

    {map, ch_select} =
      spad.map
      |> Enum.take(spad.y_size)
      |> Enum.map(fn row -> Enum.take(row, spad.x_size) end)
      |> Enum.reverse()
      |> transpose()
      |> Enum.reduce({"", 0}, fn row, {acc, ch_select} ->
        {encoded, new_ch_select} = encode_map_row(row |> Enum.reverse())
        {acc <> encoded, new_ch_select ||| ch_select}
      end)

    map = map |> String.pad_trailing(0x89 - 0x41, <<0x00>>)

    mask <>
      map <>
      Util.encode_int_3(ch_select) <> <<spad.x_offset, spad.y_offset, spad.x_size, spad.y_size>>
  end

  defp encode_mask_row(row) do
    row
    |> Enum.chunk_every(8)
    |> Enum.map(fn byte ->
      byte |> Enum.reverse() |> Enum.reduce(0, fn b, acc -> (acc <<< 1) + b end)
    end)
  end

  defp encode_map_row(row) do
    {encoded, ch_select} =
      row
      |> Enum.reverse()
      |> Enum.with_index()
      |> Enum.reduce({0, 0}, fn {channel, y}, {acc, ch_select} ->
        {a, new_ch_select} = encode_channel(channel, y, ch_select)
        {acc ||| a, new_ch_select}
      end)

    {Util.encode_int_4(encoded), ch_select}
  end

  @tmf8x2x_main_spad_vertical_lsb_shift 0
  @tmf8x2x_main_spad_vertical_mid_shift 10
  @tmf8x2x_main_spad_vertical_msb_shift 20

  defp decode_channel(i, y, ch_select) do
    res =
      (i >>> (@tmf8x2x_main_spad_vertical_lsb_shift + y) &&& 0x1) |||
        (i >>> (@tmf8x2x_main_spad_vertical_mid_shift + y) <<< 1 &&& 0x2) |||
        (i >>> (@tmf8x2x_main_spad_vertical_msb_shift + y) <<< 2 &&& 0x4)

    ch_select_bit_set = Util.bit_set?(ch_select, y)

    res =
      cond do
        ch_select_bit_set and res == 0 -> 8
        ch_select_bit_set and res == 1 -> 9
        true -> res
      end

    res
  end

  defp encode_channel(8, y, ch_select) do
    {0, ch_select ||| 1 <<< y}
  end

  defp encode_channel(9, y, ch_select) do
    {1 <<< (@tmf8x2x_main_spad_vertical_lsb_shift + y), ch_select ||| 1 <<< y}
  end

  defp encode_channel(channel, y, ch_select) do
    res =
      (channel &&& 1) <<< (@tmf8x2x_main_spad_vertical_lsb_shift + y) |||
        (channel &&& 2) >>> 1 <<< (@tmf8x2x_main_spad_vertical_mid_shift + y) |||
        (channel &&& 4) >>> 2 <<< (@tmf8x2x_main_spad_vertical_msb_shift + y)

    {res, ch_select}
  end

  defp transpose(a), do: a |> List.zip() |> Enum.map(&Tuple.to_list/1)

  defp pad(list, count, item) when count > 0 do
    [item | list |> Enum.reverse()] |> Enum.reverse() |> pad(count - 1, item)
  end

  defp pad(list, _, _), do: list
end

defmodule TMF882X.Util do
  @moduledoc """
  Utilities for working with messages from the TMF882X
  """
  import Bitwise

  @doc """
  Returns true if a given bit position set, false otherwise.
  """
  @spec bit_set?(number(), non_neg_integer()) :: boolean()
  def(bit_set?(a, bit) when is_integer(a)) do
    (a >>> bit &&& 0x01) == 1
  end

  def bit_set?(<<a>>, bit), do: bit_set?(a, bit)

  @doc """
  Returns the first byte of the binary
  """
  @spec extract_int_1(binary()) :: byte()
  def extract_int_1(<<a, _::bits>>), do: a

  @doc """
  Returns the integer represented by the first two bytes of the binary
  """
  @spec extract_int_2(binary()) :: non_neg_integer()
  def extract_int_2(<<a, b, _::bits>>), do: a + (b <<< 8)

  @doc """
  Returns the integer represented by the first three bytes of the binary
  """
  @spec extract_int_3(binary()) :: non_neg_integer()
  def extract_int_3(<<a, b, c, _::bits>>), do: a + (b <<< 8) + (c <<< 16)

  @doc """
  Returns the integer represented by the first four bytes of the binary
  """
  @spec extract_int_4(binary()) :: non_neg_integer()
  def extract_int_4(<<a, b, c, d, _::bits>>), do: a + (b <<< 8) + (c <<< 16) + (d <<< 24)

  @doc """
  Returns the integer represented by the byte of the binary at position `address` if the first byte of the binary is at position `start`.
  """
  def extract_int_1_at(data, address, start \\ 0x00),
    do: data |> drop(address - start) |> extract_int_1()

  @doc """
  Returns the integer represented by the two bytes of the binary at position `address` if the first byte of the binary is at position `start`.
  """
  def extract_int_2_at(data, address, start \\ 0x00),
    do: data |> drop(address - start) |> extract_int_2()

  @doc """
  Returns the integer represented by the three bytes of the binary at position `address` if the first byte of the binary is at position `start`.
  """
  def extract_int_3_at(data, address, start \\ 0x00),
    do: data |> drop(address - start) |> extract_int_3()

  @doc """
  Returns the integer represented by the four bytes of the binary at position `address` if the first byte of the binary is at position `start`.
  """
  def extract_int_4_at(data, address, start \\ 0x00),
    do: data |> drop(address - start) |> extract_int_4()

  @doc """
  Returns an array of integer extracted three bytes at a time until either `count` integers are found or the end of the binary is reached.
  """
  @spec extract_multi_int_3(binary(), byte(), byte(), non_neg_integer()) :: list(non_neg_integer)
  def extract_multi_int_3(data, address, start, count) do
    data |> drop(address - start) |> do_extract_multi_int_3(count)
  end

  defp do_extract_multi_int_3(<<a, b, c, rest::bits>>, remain) when remain > 0 do
    [a + (b <<< 8) + (c <<< 16) | do_extract_multi_int_3(rest, remain - 1)]
  end

  defp do_extract_multi_int_3(_, _), do: []

  @doc """
  Returns an array of integer extracted four bytes at a time until either `count` integers are found or the end of the binary is reached.
  """
  @spec extract_multi_int_4(binary(), byte(), byte(), non_neg_integer()) :: list(non_neg_integer)
  def extract_multi_int_4(data, address, start, count) do
    data |> drop(address - start) |> do_extract_multi_int_4(count)
  end

  defp do_extract_multi_int_4(<<a, b, c, d, rest::bits>>, remain) when remain > 0 do
    [a + (b <<< 8) + (c <<< 16) + (d <<< 24) | do_extract_multi_int_4(rest, remain - 1)]
  end

  defp do_extract_multi_int_4(_, _), do: []

  defp drop(data, count) do
    <<_::binary-size(count), rest::bits>> = data
    rest
  end

  @doc """
  Encodes an integer as a single byte binary
  """
  @spec encode_int_1(non_neg_integer()) :: binary()
  def encode_int_1(a), do: <<a>>

  @doc """
  Encodes an integer as a 2-byte binary
  """
  @spec encode_int_2(non_neg_integer()) :: binary()
  def encode_int_2(a), do: <<a &&& 0xFF, a >>> 8>>

  @doc """
  Encodes an integer as a 3-byte binary
  """
  @spec encode_int_3(non_neg_integer()) :: binary()
  def encode_int_3(a), do: <<a &&& 0xFF, a >>> 8 &&& 0xFF, a >>> 16>>

  @doc """
  Encodes an integer as a 4-byte binary
  """
  @spec encode_int_4(non_neg_integer()) :: binary()
  def encode_int_4(a), do: <<a &&& 0xFF, a >>> 8 &&& 0xFF, a >>> 16 &&& 0xFF, a >>> 24 &&& 0xFF>>
end

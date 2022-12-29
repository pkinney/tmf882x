defmodule TMF882X.Result do
  @moduledoc """
  Encodes and decodes the contents of the measurement register.
  """
  defstruct ~w(tid size number temperature valid_results ambient photon_count reference_count sys_tick measurements)a

  import Bitwise
  alias TMF882X.Util
  @type t() :: %__MODULE__{}

  @doc """
  Creates a new Result from the contents of the result register (0x20).  This assumes
  the binary starts with at `0x20` and includes the `cid_rid` value of `0x10`.
  """
  @spec new(binary()) :: t()
  def new(<<0x10, _::bits>> = data) do
    %__MODULE__{
      tid: Util.extract_int_1_at(data, 0x21, 0x20),
      size: Util.extract_int_1_at(data, 0x22, 0x20),
      number: Util.extract_int_1_at(data, 0x24, 0x20),
      temperature: Util.extract_int_1_at(data, 0x25, 0x20),
      valid_results: Util.extract_int_1_at(data, 0x26, 0x20),
      ambient: Util.extract_int_4_at(data, 0x28, 0x20),
      photon_count: Util.extract_int_4_at(data, 0x2C, 0x20),
      reference_count: Util.extract_int_4_at(data, 0x30, 0x20),
      sys_tick: Util.extract_int_4_at(data, 0x34, 0x20),
      measurements: extract_measurements(data)
    }
  end

  defp extract_measurements(<<_::binary-size(24), rest::bits>>) do
    do_extract_measurements(rest, 130)
  end

  defp do_extract_measurements(<<conf, d1, d2, rest::bits>>, remain) when remain > 0 do
    [{d1 + (d2 <<< 8), conf} | do_extract_measurements(rest, remain - 1)]
  end

  defp do_extract_measurements(_, _), do: []
end

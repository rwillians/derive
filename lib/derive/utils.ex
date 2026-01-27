defmodule Derive.Utils do
  @moduledoc false

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  # PRIVATE MODULE DISCLAIMER                                       #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  # This module is meant to be used internally by Derive only!      #
  #                                                                 #
  # There's no guarantee of stability for its API. It might change  #
  # between released regardless of the release type (major, minor   #
  # or patch).                                                      #
  #                                                                 #
  # If you're importing `derive`: DO NOT USE THIS MODULE!           #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Pattern matches an Ecto schema of the given module.

  ## Examples

  Can match a specific Ecto schema:

      iex> case %Dummy.User{} do
      iex>   ecto_schema(Dummy.User) -> :matched
      iex>   _ -> :not_matched
      iex> end
      :matched

      iex> case %Dummy.Inbox{} do
      iex>   ecto_schema(Dummy.User) -> :matched
      iex>   _ -> :not_matched
      iex> end
      :not_matched

  Can match any Ecto schema:

      iex> case %Dummy.User{} do
      iex>   ecto_schema(_) -> :matched
      iex>   _ -> :not_matched
      iex> end
      :matched

      iex> case %Dummy.Inbox{} do
      iex>   ecto_schema(_) -> :matched
      iex>   _ -> :not_matched
      iex> end
      :matched

  Doesn't match non-Ecto schemas:

      iex> case %Dummy{} do
      iex>   ecto_schema(_) -> :matched
      iex>   _ -> :not_matched
      iex> end
      :not_matched

  """

  defmacro ecto_schema(mod) do
    quote do
      %unquote(mod){__meta__: _}
    end
  end

  @doc ~S"""
  Merges a set of AST blocks into a single block.

  ## Examples

  Preserves the order of statements:

      iex> blocks = [
      iex>   {:__block__, [], [:foo, :bar]},
      iex>   {:__block__, [], [:baz]},
      iex>   :qux
      iex> ]
      iex>
      iex> merge_blocks(blocks)
      {:__block__, [], [:foo, :bar, :baz, :qux]}

  When given an empty list, returns an empty block:

      iex> merge_blocks([])
      {:__block__, [], []}

  """

  @spec merge_blocks([block | statement]) :: block
        when block: {:__block__, [], [statement, ...]},
             statement: Macro.t()

  @empty_block {:__block__, [], []}

  def merge_blocks([]), do: @empty_block
  def merge_blocks([_ | _] = blocks), do: Enum.reduce(blocks, @empty_block, &merge_blocks/2)

  @doc ~S"""
  Merges two AST blocks into a single block.

  ## Examples

  The second argument's statements come first in the resulting block
  because `merge_blocks/2` is typically used with `Enum.reduce/3`
  where the accumulator is the second argument:

      iex> next = :baz
      iex> acc = {:__block__, [], [:foo, :bar]}
      iex>
      iex> merge_blocks(next, acc)
      {:__block__, [], [:foo, :bar, :baz]}

  """

  @spec merge_blocks(next, acc) :: block
        when block: {:__block__, [], [statement, ...]},
             statement: Macro.t(),
             next: block | statement,
             acc: block | statement

  def merge_blocks(next, acc), do: {:__block__, [], statments(acc) ++ statments(next)}

  defp statments({:__block__, _, statements}), do: statements
  defp statments(statement), do: [statement]

  @doc ~S"""
  Generates a unique, deterministic step name from the given value.

  ## Examples

      iex> Derive.Utils.step(:my_value)
      :"51a9405"

  Given the same value, it always generates the same result:

      iex> Derive.Utils.step(:my_value)
      :"51a9405"

  """

  def step(value) do
    :crypto.hash(:sha256, inspect(value))
    |> Base.encode16(case: :lower)
    |> String.slice(0, 7)
    |> to_atom_safe()
  end

  defp to_atom_safe(value) when is_binary(value) and byte_size(value) > 0 do
    String.to_existing_atom(value)
  rescue
    _ -> String.to_atom(value)
  end
end

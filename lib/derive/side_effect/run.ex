defmodule Derive.SideEffect.Run do
  @moduledoc ~S"""
  Runs a given function that produces side-effects.
  """

  defstruct fun: nil

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.3.2"

  def run(fun)
      when is_function(fun, 0)
      when is_function(fun, 1)
      when is_function(fun, 2),
      do: %__MODULE__{fun: fun}
end

defimpl Derive.SideEffect, for: Derive.SideEffect.Run do
  @impl Derive.SideEffect
  def append(%Derive.SideEffect.Run{fun: fun}, %Ecto.Multi{} = multi, step)
      when is_function(fun, 0),
      do: Ecto.Multi.run(multi, step, fn _, _ -> normalize(fun.()) end)

  def append(%Derive.SideEffect.Run{fun: fun}, %Ecto.Multi{} = multi, step)
      when is_function(fun, 1),
      do: Ecto.Multi.run(multi, step, fn repo, _ -> normalize(fun.(repo)) end)

  def append(%Derive.SideEffect.Run{fun: fun}, %Ecto.Multi{} = multi, step)
      when is_function(fun, 2),
      do: Ecto.Multi.run(multi, step, fn repo, acc -> normalize(fun.(repo, acc)) end)

  #
  #   PRIVATE
  #

  defp normalize(:ok), do: {:ok, nil}
  defp normalize({:ok, result}), do: {:ok, result}
  defp normalize({:error, reason}), do: {:error, reason}
  defp normalize({:error, _, reason, _}), do: {:error, reason}
  defp normalize(result), do: {:ok, result}
end

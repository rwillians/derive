defmodule Derive.Context do
  @moduledoc ~S"""
  @todo add documentation
  """
  @moduledoc since: "0.1.0"

  @typedoc ~S"""
  @todo add documentation
  """
  @typedoc since: "0.1.0"

  @type t ::
    {:ctx, put: {key :: atom | String.t(), value :: term}}
    | {:ctx, delete: key :: atom | String.t()}

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  def context_effect?({:ctx, put: _}), do: true
  def context_effect?({:ctx, delete: _}), do: true
  def context_effect?(_), do: false

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  def delete_ctx(key)
      when is_binary(key)
      when is_atom(key),
      do: {:ctx, delete: key}

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  def put_ctx(key, value)
      when is_binary(key)
      when is_atom(key),
      do: {:ctx, put: {key, value}}

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  def update_context({:ctx, put: {key, value}}, ctx), do: Map.put(ctx, key, value)
  def update_context({:ctx, delete: key}, ctx), do: Map.delete(ctx, key)
end

defmodule Derive.SideEffect.Insert do
  @moduledoc ~S"""
  @todo add documentation
  """
  @moduledoc since: "0.1.0"

  import Derive.Utils, only: [ecto_schema: 1]

  alias __MODULE__

  @typedoc ~S"""
  @todo add documentation
  """
  @typedoc since: "0.1.0"

  @type t :: %Insert{
          record: Ecto.Schema.schema(),
          conflict_target: atom | [atom],
          on_conflict:
            :nothing
            | :raise
            | :replace_all
            | :replace_all_except_primary_key
            | {:replace, [atom, ...]}
            | [{:inc, keyword} | {:set, keyword}, ...]
        }

  defstruct record: nil,
            conflict_target: nil,
            on_conflict: nil

  #
  #   ↓ PUBLIC API
  #

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @spec insert(record) :: t
        when record: Ecto.Schema.schema()

  def insert(ecto_schema(_) = record) do
    %Insert{
      record: record,
      conflict_target: nil,
      on_conflict: :raise
    }
  end

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @spec merge(record) :: t
        when record: Ecto.Schema.schema()

  def merge(ecto_schema(mod) = record) do
    params =
      record
      |> Map.from_struct()
      |> Map.drop([:__meta__])
      |> Enum.reject(fn
        {_, nil} -> true
        {_, %Ecto.Association.NotLoaded{}} -> true
        {_, ecto_schema(_)} -> true
        {_, _} -> false
      end)
      |> Map.new()

    primary_keys = mod.__schema__(:primary_key)
    update_keys = Map.keys(params) -- primary_keys

    %Insert{
      record: record,
      conflict_target: primary_keys,
      on_conflict: {:replace, update_keys}
    }
  end

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @spec upsert(record) :: t
        when record: Ecto.Schema.schema()

  def upsert(ecto_schema(_) = record) do
    record
    |> insert()
    |> on_conflict(:replace_all)
  end

  #
  #   ↓ OPTIONS API
  #

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @spec conflict_target(%Insert{}, [field, ...]) :: t
        when field: atom

  def conflict_target(%Insert{} = op, [_ | _] = fields), do: %Insert{op | conflict_target: fields}

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @spec on_conflict(%Insert{}, action) :: t
        when action:
               :raise
               | :nothing
               | :replace_all
               | :replace_all_except_primary_key
               | {:replace, [atom, ...]}
               | [{:inc, keyword} | {:set, keyword}, ...]

  def on_conflict(%Insert{} = op, :raise), do: %Insert{op | on_conflict: :raise, conflict_target: nil}
  def on_conflict(%Insert{} = op, on_conflict), do: %Insert{op | on_conflict: on_conflict}
end

defimpl Derive.SideEffect, for: Derive.SideEffect.Insert do
  import Derive.Utils, only: [step: 1]

  @impl Derive.SideEffect
  def append(%Derive.SideEffect.Insert{} = op, %Ecto.Multi{} = multi) do
    opts = [
      conflict_target: op.conflict_target,
      on_conflict: op.on_conflict,
      returning: false
    ]

    Ecto.Multi.insert(multi, step(op), op.record, opts)
  end
end

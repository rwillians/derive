defmodule Derive.SideEffect.Delete do
  @moduledoc ~S"""
  @todo add documentation
  """
  @moduledoc since: "0.1.0"

  import Ecto.Query

  alias __MODULE__

  @typedoc ~S"""
  @todo add documentation
  """
  @typedoc since: "0.1.0"

  @type t :: %Delete{
          query: Ecto.Queryable.t()
        }

  defstruct query: nil

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @spec delete(query | filter) :: t
        when query: Ecto.Queryable.t(),
             filter: {module, [{field, term}, ...]},
             field: atom

  def delete(query_or_filter) do
    query =
      with {mod, [{_, _} | _] = filters} when is_atom(mod) <- query_or_filter,
           do: from(rec in mod, where: ^filters)

    %Delete{query: query}
  end
end

defimpl Derive.SideEffect, for: Derive.SideEffect.Delete do
  import Derive.Utils, only: [step: 1]

  @impl Derive.SideEffect
  def append(%Derive.SideEffect.Delete{} = op, %Ecto.Multi{} = multi) do
    Ecto.Multi.delete_all(multi, step(op), op.query)
  end
end

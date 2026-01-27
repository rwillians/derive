defmodule Derive.SideEffect.Update do
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

  @type t :: %Update{
          query: Ecto.Queryable.t(),
          update: [{:inc, keyword} | {:set, keyword}, ...]
        }

  defstruct query: nil,
            update: nil

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @spec update(query | filter, params | [update, ...]) :: %Update{}
        when query: Ecto.Queryable.t(),
             filter: {module, [{field, term}, ...]},
             field: atom,
             params: %{atom => term},
             update: {:inc, keyword} | {:set, keyword}

  def update(query_or_filter, params) when is_non_struct_map(params) do
    query =
      with {mod, [{_, _} | _] = filters} when is_atom(mod) <- query_or_filter,
           do: from(rec in mod, where: ^filters)

    %Update{query: query, update: [set: Map.to_list(params)]}
  end

  def update(query_or_filter, updates) when is_list(updates) do
    query =
      with {mod, [{_, _} | _] = filters} when is_atom(mod) <- query_or_filter,
           do: from(rec in mod, where: ^filters)

    {inc, updates} = Keyword.pop(updates, :inc)
    {set, other} = Keyword.pop(updates, :set)

    for {key, _} <- other,
        do: raise(ArgumentError, "unsupported option #{inspect(key)}")

    update =
      case {inc, set} do
        {nil, nil} -> raise(ArgumentError, "at least one of :inc and :set must have a value, they are both nil")
        {inc, nil} -> [inc: inc]
        {nil, set} -> [set: set]
        {inc, set} -> [inc: inc, set: set]
      end

    %Update{query: query, update: update}
  end
end

defimpl Derive.SideEffect, for: Derive.SideEffect.Update do
  import Derive.Utils, only: [step: 1]

  @impl Derive.SideEffect
  def append(%Derive.SideEffect.Update{} = op, %Ecto.Multi{} = multi) do
    Ecto.Multi.update_all(multi, step(op), op.query, op.update, returning: false)
  end
end

defprotocol Derive.SideEffect do
  @moduledoc ~S"""
  @todo add documentation
  """
  @moduledoc since: "0.1.0"

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @spec append(t, multi) :: multi
        when multi: Ecto.Multi.t()

  def append(side_effect, multi)
end

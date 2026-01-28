defmodule Derive do
  @moduledoc ~S"""
  @todo add documentation
  """
  @moduledoc since: "0.1.0"

  use GenServer

  import DateTime, only: [utc_now: 0]
  import Derive.Context, only: [context_effect?: 1, update_context: 2]
  import Derive.SideEffect, only: [append: 2]

  alias __MODULE__, as: State
  alias Derive.Cursor
  alias Ecto.Multi

  require Logger

  @typedoc ~S"""
  @todo add documentation
  """
  @typedoc since: "0.1.0"

  @type event() :: %{
          required(:id) => pos_integer,
          optional(atom) => any
        }

  @typedoc ~S"""
  @todo add documentation
  """
  @typedoc since: "0.1.0"

  @type position :: non_neg_integer

  @typedoc ~S"""
  @todo add documentation
  """
  @typedoc since: "0.1.0"

  @type reason :: binary | Exception.t() | term

  @typedoc ~S"""
  @todo add documentation
  """
  @typedoc since: "0.1.0"

  @type record :: Ecto.Schema.schema()

  @typedoc ~S"""
  @todo add documentation
  """
  @typedoc since: "0.1.0"

  @type repo :: Ecto.Repo.t()

  @typedoc ~S"""
  @todo add documentation, make sure to include the points below

  Key points:
  * a side effect can be any struct that implements the
    Derive.SideEffect protocol
  """
  @typedoc since: "0.1.0"

  @type side_effect :: Derive.SideEffect.t()

  @typedoc ~S"""
  @todo add documentation
  """
  @typedoc since: "0.1.0"

  @type t :: %State{
          consumer: module,
          repo: Ecto.Repo.t(),
          batch_size: pos_integer,
          filters: [{atom, term}, ...],
          cursor: %Derive.Cursor{},
          ctx: map,
          timer: reference | nil,
          error_count: non_neg_integer
        }

  @typedoc ~S"""
  @todo add documentation
  """
  @typedoc since: "0.1.0"

  @type state :: t

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback dump_ctx(repo, old_ctx, new_ctx) :: :ok
            when old_ctx: map,
                 new_ctx: map

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback fetch(repo, [filter | option, ...]) :: [event]
            when filter: {atom, term},
                 option: {:after, position} | {:take, pos_integer}

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback handle_event(event, ctx) :: [side_effect]
            when ctx: map

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback load_ctx(repo) :: map

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback persist(repo, [side_effect, ...]) :: :ok | {:error, reason}

  defstruct consumer: nil,
            repo: nil,
            batch_size: nil,
            filters: nil,
            cursor: nil,
            ctx: nil,
            timer: nil,
            error_count: 0

  #
  #   ↓ MACROS
  #

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  defmacro __using__(opts) do
    {otp_app, opts} = Keyword.pop!(opts, :otp_app)

    unless is_atom(otp_app),
      do: raise(ArgumentError, ":otp_app option is required and must be an atom")

    for {key, _} <- opts,
        do: raise(ArgumentError, "Unknown option #{inspect(key)}")

    quote do
      @behaviour unquote(__MODULE__)

      import unquote(__MODULE__), only: [into_multi: 1, into_multi: 2]
      import Derive.Context, only: [put_ctx: 2]
      import Derive.SideEffect.Delete
      import Derive.SideEffect.Insert
      import Derive.SideEffect.Update

      @doc false
      @spec child_spec([option]) :: map
            when option:
              {:name, atom}
              | {:repo, Ecto.Repo.t()}
              | {:filters, keyword}
              | {:batch_size, pos_integer}

      def child_spec(opts \\ []) do
        repo =
          unquote(otp_app)
          |> Application.get_env(:ecto_repos, [])
          |> List.first()

        opts =
          opts
          |> Keyword.put(:consumer, __MODULE__)
          |> Keyword.put_new(:name, __MODULE__)
          |> Keyword.put_new(:repo, repo)

        %{
          id: opts[:name],
          start: {unquote(__MODULE__), :start_link, [opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 5_000
        }
      end

      @impl unquote(__MODULE__)
      def load_ctx(_), do: %{}

      @impl unquote(__MODULE__)
      def dump_ctx(_, _, _), do: :ok

      @impl unquote(__MODULE__)
      def persist(repo, [_ | _] = side_effects) do
        case repo.transact(into_multi(side_effects)) do
          {:ok, _} -> :ok
          {:error, _, reason, _} -> {:error, reason}
        end
      end

      defoverridable load_ctx: 1,
                     dump_ctx: 3,
                     persist: 2
    end
  end

  #
  #   ↓ PUBLIC API
  #

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @spec into_multi([side_effect], multi) :: multi
        when multi: Ecto.Multi.t()

  def into_multi(side_effects, multi \\ Multi.new())
  def into_multi([], %Multi{} = multi), do: multi
  def into_multi([_ | _] = side_effects, %Multi{} = multi), do: Enum.reduce(side_effects, multi, &append/2)

  #
  #   ↓ GENSERVER API
  #

  @doc false
  def start_link(opts \\ []) do
    {link_opts, opts} = Keyword.split(opts, [:timeout, :debug, :spawn_opt, :hibernate_after])
    name = Keyword.fetch!(opts, :name)

    GenServer.start_link(__MODULE__, opts, [name: name] ++ link_opts)
  end

  @impl GenServer
  @doc false
  def init(opts) do
    {consumer, opts} = Keyword.pop!(opts, :consumer)
    {name, opts} = Keyword.pop(opts, :name, consumer)
    {repo, opts} = Keyword.pop!(opts, :repo)
    {filters, opts} = Keyword.pop(opts, :filters, [])
    {batch_size, opts} = Keyword.pop(opts, :batch_size, 100)

    unless is_atom(consumer) and Code.ensure_loaded?(consumer),
      do: raise(ArgumentError, "Expected :consumer to be an existing module, got #{inspect(consumer)}")

    unless is_atom(name),
      do: raise(ArgumentError, "Expected :name to be an atom, got #{inspect(name)}")

    unless is_atom(repo) and Code.ensure_loaded?(repo),
      do: raise(ArgumentError, "Expected :repo to be an existing module, got #{inspect(repo)}")

    unless Keyword.keyword?(filters),
      do: raise(ArgumentError, "Expected :filters to be a keyword list, got #{inspect(filters)}")

    unless is_integer(batch_size) and batch_size > 0,
      do: raise(ArgumentError, "Expected :batch_size to be a positive integer, got #{inspect(batch_size)}")

    for {key, _} <- opts,
        do: raise(ArgumentError, "Unsupported option #{inspect(key)}")

    ctx = consumer.load_ctx(repo)

    unless is_non_struct_map(ctx),
      do: raise(ArgumentError, "Expected #{inspect(consumer)}.load_ctx/1 to return a non-struct map, got #{inspect(ctx)}")

    state =
      %State{
        consumer: consumer,
        repo: repo,
        filters: filters,
        batch_size: batch_size,
        cursor: Derive.Cursor.resolve!(repo, name),
        ctx: ctx
      }

    Logger.metadata([consumer: name])

    {:ok, state, {:continue, :ingest}}
  end

  @impl GenServer
  @doc false
  def handle_continue(:ingest, %State{} = state) do
    case process(state) do
      {:ok, state, events} ->
        Logger.debug("Ingestion succeeded, processed #{length(events)} new events")
        {:noreply, progressed(state, to: last_position(events)), {:continue, :ingest}}

      :end_of_stream ->
        Logger.debug("End of stream reached, will sleep for 5 seconds...")
        timer = Process.send_after(self(), :continue, 5_000)
        {:noreply, up_to_date(state, timer)}

      {:error, reason} ->
        Logger.error("Ingestion failed: #{Exception.format(:error, reason)}")
        timeout = backoff(state.error_count + 1)
        Logger.debug("Backing off for #{trunc(timeout / 1_000)} seconds")
        timer = Process.send_after(self(), :continue, timeout)
        {:noreply, failed(state, reason, timer)}
    end
  end

  @impl GenServer
  @doc false
  def handle_info(:continue, state), do: {:noreply, state, {:continue, :ingest}}

  #
  #   ↓ STATE API
  #

  defp progressed(state, to: new_position) do
    cursor =
      state.cursor
      |> Cursor.changeset(%{position: new_position, last_synced_at: utc_now(), stuck_since: nil, stuck_reason: nil})
      |> state.repo.update!()

    %{
      state
      | cursor: cursor,
        error_count: 0
    }
  end

  defp up_to_date(state, timer) do
    cursor =
      state.cursor
      |> Cursor.changeset(%{last_synced_at: utc_now(), stuck_since: nil, stuck_reason: nil})
      |> state.repo.update!()

    %{
      state
      | cursor: cursor,
        timer: timer,
        error_count: 0
    }
  end

  defp failed(state, reason, timer) do
    cursor =
      state.cursor
      |> Cursor.changeset(%{stuck_since: utc_now(), stuck_reason: Exception.format(:error, reason)})
      |> state.repo.update!()

    %{
      state
      | cursor: cursor,
        timer: timer,
        error_count: state.error_count + 1
    }
  end

  #
  #   ↓ PROCESSING API
  #

  defp process(%State{consumer: consumer} = state) do
    filters =
      state.filters
      |> Keyword.put(:after, state.cursor.position)
      |> Keyword.put(:take, state.batch_size)

    with {:ok, [_ | _] = events} <- fetch(state.consumer, state.repo, filters),
         {:ok, side_effects, new_ctx} <- handle_events(events, state.ctx, with: &consumer.handle_event/2),
         :ok <- persist(state.repo, side_effects, with: &consumer.persist/2),
         :ok <- consumer.dump_ctx(state.repo, state.ctx, new_ctx),
         do: {:ok, %{state | ctx: new_ctx}, events}
  end

  defp fetch(consumer, repo, filters) do
    case consumer.fetch(repo, filters) do
      [_ | _] = events -> {:ok, events}
      #      ↓ [e]nd [o]f [s]tream
      [] -> :end_of_stream
    end
  end

  defp handle_events(events, persisted_ctx, with: handler) do
    {side_effects, working_ctx} =
      Enum.reduce(events, {[], persisted_ctx}, fn event, {acc_side_effects, acc_ctx} ->
        {ctx_side_effects, new_side_effects} =
          handler.(event, acc_ctx)
          |> normalize()
          |> Enum.split_with(&context_effect?/1)

        new_ctx = Enum.reduce(ctx_side_effects, acc_ctx, &update_context/2)

        {acc_side_effects ++ new_side_effects, new_ctx}
      end)

    {:ok, side_effects, working_ctx}
  rescue
    reason -> {:error, reason}
  end

  defp normalize(:skip), do: []
  defp normalize([]), do: []
  defp normalize([_ | _] = side_effects), do: side_effects
  defp normalize(%_{} = side_effect), do: [side_effect]

  defp persist(_, [], _), do: :ok
  defp persist(repo, side_effects, with: handler), do: handler.(repo, side_effects)

  defp last_position([_ | _] = events), do: List.last(events).id

  defp backoff(attempt, base_ms \\ 100, max_ms \\ 300_000) do
    delay = min(base_ms * Integer.pow(2, attempt), max_ms)
    jitter = :rand.uniform(delay)

    jitter
  end
end

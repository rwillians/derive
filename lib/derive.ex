defmodule Derive do
  @moduledoc ~S"""
  @todo add documentation
  """
  @moduledoc since: "0.1.0"

  use GenServer

  import DateTime, only: [utc_now: 0]
  import Derive.SideEffect, only: [append: 3]

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

  @callback fetch(repo, [filter | option, ...]) :: [event]
            when filter: {atom, term},
                 option: {:after, position} | {:take, pos_integer}

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback prepare(event) :: event | :skip

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback handle_event(event) :: [side_effect] | :skip

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback persist(repo, [side_effect, ...]) :: :ok | {:error, reason}

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback on_persisted(repo, [event, ...]) :: any | no_return

  @doc ~S"""
  @todo add documentation
  """
  @doc since: "0.1.0"

  @callback on_failed(repo, reason :: term) :: any | no_return

  defstruct consumer: nil,
            repo: nil,
            batch_size: nil,
            filters: nil,
            cursor: nil,
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
    {batch_size, opts} = Keyword.pop(opts, :batch_size, 100)

    unless is_atom(otp_app),
      do: raise(ArgumentError, ":otp_app option is required and must be an atom")

    unless is_integer(batch_size) and batch_size > 0,
      do: raise(ArgumentError, ":batch_size option must be a positive integer")

    for {key, _} <- opts,
        do: raise(ArgumentError, "Unknown option #{inspect(key)}")

    quote do
      @behaviour unquote(__MODULE__)

      import unquote(__MODULE__), only: [into_multi: 1, into_multi: 2]
      import Derive.SideEffect.Delete
      import Derive.SideEffect.Insert
      import Derive.SideEffect.Run
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
          |> Keyword.put_new(:batch_size, unquote(batch_size))

        %{
          id: opts[:name],
          start: {unquote(__MODULE__), :start_link, [opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 5_000
        }
      end

      @impl unquote(__MODULE__)
      def prepare(event), do: event

      @impl unquote(__MODULE__)
      def persist(repo, [_ | _] = side_effects) do
        case repo.transact(into_multi(side_effects)) do
          {:ok, _} -> :ok
          {:error, _, reason, _} -> {:error, reason}
        end
      end

      @impl unquote(__MODULE__)
      def on_persisted(_, _), do: :ok

      @impl unquote(__MODULE__)
      def on_failed(_, _), do: :ok

      defoverridable prepare: 1,
                     persist: 2,
                     on_persisted: 2,
                     on_failed: 2
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

  def into_multi([_ | _] = side_effects, %Multi{} = multi) do
    side_effects
    |> Enum.with_index()
    |> Enum.reduce(multi, fn {side_effect, index}, acc ->
      append(side_effect, acc, to_atom_safe("side_effect_#{index}"))
    end)
  end

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
    {batch_size, opts} = Keyword.pop!(opts, :batch_size)
    {filters, opts} = Keyword.pop(opts, :filters, [])

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

    state =
      %State{
        consumer: consumer,
        repo: repo,
        filters: filters,
        batch_size: batch_size,
        cursor: Derive.Cursor.resolve!(repo, name)
      }

    Logger.metadata(consumer: name)

    {:ok, state, {:continue, :ingest}}
  end

  @impl GenServer
  @doc false
  def handle_continue(:ingest, %State{} = state) do
    case process(state) do
      {:ok, state, events} ->
        Logger.debug("ingestion succeeded, processed #{length(events)} new events")
        {:noreply, progressed(state, to: last_position(events)), {:continue, :ingest}}

      :end_of_stream ->
        Logger.debug("up to date, will sleep for 5 seconds...")
        timer = Process.send_after(self(), :resume, :timer.seconds(5))
        {:noreply, up_to_date(state, timer)}

      {:error, reason} ->
        Logger.error(Exception.format(:error, reason))
        timeout = backoff(state.error_count + 1)
        timer = Process.send_after(self(), :resume, timeout)
        {:noreply, failed(state, reason, timer)}
    end
  end

  @impl GenServer
  @doc false
  def handle_info(:resume, state), do: {:noreply, state, {:continue, :ingest}}

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

  defp process(%State{consumer: consumer, repo: repo} = state) do
    filters =
      state.filters
      |> Keyword.put(:after, state.cursor.position)
      |> Keyword.put(:take, state.batch_size)

    with {:ok, [_ | _] = events} <- fetch(consumer, repo, filters),
         {:ok, prepared_events} <- prepare_events(events, with: &consumer.prepare/1),
         {:ok, side_effects} <- handle_events(prepared_events, with: &consumer.handle_event/1),
         :ok <- persist(repo, side_effects, with: &consumer.persist/2),
         _ <- consumer.on_persisted(repo, events) do
      #              because skipped events on prepare_events/2 are
      #            ↓ considered as "handled"
      {:ok, state, events}
    else
      :end_of_stream ->
        :end_of_stream

      {:error, reason} ->
        _ = consumer.on_failed(repo, reason)
        {:error, reason}
    end
  end

  defp fetch(consumer, repo, filters) do
    case consumer.fetch(repo, filters) do
      [_ | _] = events -> {:ok, events}
      #      ↓ [e]nd [o]f [s]tream
      [] -> :end_of_stream
    end
  rescue
    reason -> {:error, reason}
  catch
    reason -> {:error, reason}
  end

  defp prepare_events(events, with: handler) do
    prepared_events =
      events
      |> Enum.map(handler)
      |> Enum.reject(&(&1 == :skip))

    {:ok, prepared_events}
  end

  defp handle_events(events, with: handler) do
    {:ok, Enum.flat_map(events, &normalize(handler.(&1)))}
  rescue
    reason -> {:error, reason}
  catch
    reason -> {:error, reason}
  end

  defp normalize(:skip), do: []
  defp normalize([]), do: []
  defp normalize([_ | _] = side_effects), do: side_effects
  defp normalize(%_{} = side_effect), do: [side_effect]

  defp persist(_, [], _), do: :ok

  defp persist(repo, side_effects, with: handler) do
    handler.(repo, side_effects)
  rescue
    reason -> {:error, reason}
  catch
    reason -> {:error, reason}
  end

  defp to_atom_safe(string) do
    String.to_existing_atom(string)
  rescue
    _ -> String.to_atom(string)
  end

  defp last_position([_ | _] = events), do: List.last(events).id

  defp backoff(attempt, base_ms \\ :timer.seconds(1), max_ms \\ :timer.minutes(5)) do
    delay = min(base_ms * Integer.pow(2, attempt), max_ms)
    jitter = :rand.uniform(delay)

    jitter
  end
end

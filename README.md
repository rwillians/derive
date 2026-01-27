# derive

A small, simple, and yet flexible API for deriving state from an event source, that works out of the box with [Ecto](https://hexdocs.pm/ecto).

It comes ships with all the essential side-effects:
- insert
- update
- merge
- upsert
- delete

If you need more exotic / complex side-effects, you can easily create your own by implementing the `Derive.SideEffect` protocol for your custom side-effect structs.

## show me the code

Here's the most basic example I can thnk of:

```elixir
# priv/repo/migrations/20260127044710_create_derive_tables.exs
defmodule Dummy.Repo.Migrations.CreateDerivedTables do
  use Derive.Migration

  def up do
    Derive.Migration.up(1)
  end

  def down do
    Derive.Migration.down(1)
  end
end

# lib/dummy.ex
defmodule Dummy.Application do
  use Application

  def start(_, _) do
    children = [
      Dummy.Repo,
      Dummy.Consumer # {Dummy.Consumer, filters: [customer_id: 167810624]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Dummy.Supervisor)
  end
end

# lib/dummy/consumer.ex
defmodule Dummy.Consumer do
  use Derive, otp_app: :dummy

  @impl Derive
  def fetch_events(repo, filters) do
    filters
    |> Dummy.Inbox.query()
    |> repo.all()
    |> Enum.map(&Dummy.Inbox.to_event/1)
  end

  @impl Derive
  def handle_event(%LoginFailed{timestamp: ts} = event) do
    [
      insert(%Dummy.SecurityIncident{
        user_id: event.user_id,
        type: :login_failed,
        occurrencies: 1,
        last_occurred_at: ts
      })
      |> on_conflict(inc: [ocurrencies: 1], set: [last_occurred_at: ts])
    ]
  end

  def handle_event(_), do: :skip
end
```

And here's an example with "director's commentary on":

```elixir
# priv/repo/migrations/20260127044710_create_derive_tables.exs
defmodule Dummy.Repo.Migrations.CreateDerivedTables do
  use Derive.Migration
  # ↑ - be sure to use derive's migration module instead of
  #     Ecto.Migration
  #   - turns out it takes a lot of code to provide an easy-to-use
  #     migration API - I was lazy, so I just put together a couple
  #     macros
  #   - the options were that you either would have to:
  #     a) add a `require Derive.Migration` to the migration file; or
  #     b) `use Derive.Migration`
  #     the latter felt less awkward, just personal preference
  #   - if you don't want to / can't do `use Derive.Migration` that's
  #     ok, just do `require Derive.Migration` instead so that you can
  #     use the `change/1` macro

  def up do
    Derive.Migration.up(1)
  end

  def down do
    Derive.Migration.down(1)
  end
end

# lib/dummy.ex
defmodule Dummy.Application do
  use Application

  def start(_, _) do
    children = [
      Dummy.Repo,
      # ↓ simplest setup
      Dummy.Consumer,
      #   - alternatively you can provide filters to produce different
      #     event streams for the same consumer module
      #   - this is particularly useful when you want to parallelize
      #     processing of events by a sharding key, like :customer_id
      #   - you could have a Supervisor dedicated to managing a bunch
      #     of consumers, or even a DynamicSupervisor if you need to
      # ↓   spawn consumers on demand
      {Dummy.Consumer, filters: [customer_id: 167810624]}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Dummy.Supervisor)
  end
end

# lib/dummy/consumer.ex
defmodule Dummy.Consumer do
  use Derive,
    # ↓ derive figures out the ecto repo from your configs
    otp_app: :dummy

  @impl Derive
  #   - fetches the next batch of events
  #   - store events however you want, wherever you want - it doesn't
  # ↓   have to be in an ecto repo, could be an API call for example
  def fetch_events(repo, filters) do
    filters
    # ↑ - filters is a keyword list containing the filters you might
    #     have provided in the Supervisor children

    #   - derive only makes two assumptions about your application,
    #     one of them is that your event's :id is an integer sequence
    #     in chronological order - that's a big assumption, I know -,
    #     that's because derive uses :id as a cursor - I plan on
    # ↓   supporting sort-safe strings at some point
    |> Dummy.Inbox.query()
    # ↑ - besides the filters, there're two keys your `query/1`
    #     function must handle in this example - that's the second
    #     assumption:
    #     1. :after - the last processed event's :id; and
    #     2. :take - the maximum number of events to fetch
    #     you can override the default :batch_size either here or by
    #     providing :batch_size in the Supervisor children along with
    #     any filters you might have
    #   - that's the only time your code is exposed directly to the
    #     consumer's cursor, that' was unavoidable - for the resto of
    #     the time derive manages it the hood for you under
    |> repo.all()
    #   - best place to transform / normalize / filter out your events
    # ↓   before they hit `handle_event/1`
    |> Enum.map(&Dummy.Inbox.to_event/1)
  end

  @impl Derive
  def handle_event(%LoginFailed{timestamp: ts} = event) do
    [
      #   derive ships with essential side-effects, such as:
      #   - insert (can tweak options :conflict_target and :on_conflict
      #     to get the upsert behaviour);
      #   - update;
      #   - merge;
      #   - upsert (alias to insert); and
      #   - delete
      #   you can easily create your own side-effects by implementing
      #   the `Derive.SideEffect` protocol for your custom side-effect
      # ↓ structs
      insert(%Dummy.SecurityIncident{
        user_id: event.user_id,
        type: :login_failed,
        occurrencies: 1,
        last_occurred_at: ts
      })
      |> on_conflict(inc: [ocurrencies: 1], set: [last_occurred_at: ts])
    ]
  end

  def handle_event(_), do: []
  # ↑ - return an empty list to ignore the event

  # ↓ - returning :skip works too, whatever feels more natural to you
  def handle_event(_), do: :skip

  @impl Derive
  #   this is an optional callback, when implemented it allows you to
  # ↓ override the persistence logic
  def persist(repo, side_effects, multi) do
    multi = into_multi(side_effects, multi)
    # ↑ - by default, derive accumulates the side-effects of a batch
    #     of events into a multi and then persists them in a single
    #     transaction, but you can optionally implement your own
    #     persistence logic in this function
    #   - you can choose how much you want to override, if you just
    #     want to override like the ecto repo to persist to, you don't
    #     have to re-implement the whole thing - the logic for
    #     accumulating side-effects into a multi is available via the
    #     `into_multi/2` function
    #   - beware though that the multi received by this function isn't
    #     empty, it already includes cursor operations, meaning you
    #     need to transact it regardless of your strategy for state
    #     persistence

    case custom_logic(repo, multi) do
      {:ok, _} -> :ok
      # ↑ - by returning `:ok` derive assumes it can move on to the
      #     next batch of events
      {:error, _, reason, _} -> {:error, reason}
      # ↑ - errors will bubble up to some function that will log and
      #     handle it appropriately
      #   - you can find a copy of the error in the consumer's cursor
      #     record in the database, along with the :stuck_since
      #     timestamp
    end
  end
end
```

As promised, the API's surface is small and designed to both:
* **just work** for the intended use case where we source events and persist state changes to an ecto repo;
* be **easily extensible / overridable** for more exotic / complex use-cases.

## scope

* **In Scope** - all the code needed to reduce events into persisted state changes, including:
  * consuming an event source / forming an event streams, easy to override it with your own sourcing logic to supports sources other than an Ecto table
  * essetial side-effects, easy to create your own
  * persisting state changes to an Ecto repo, easy to override it with your own persistence logic
  * parallelizing event processing
  * tracking processing progress via cursors
  * persisting state changes
* **Out of Scope**, as in I have no plans at all - everything related to producing, persisting, broadcasting or synchronizing events.
* **Unclear Scope** - honestly, I'll only pay attention to these if I personally need them:
  * event versioning
  * event schemas / validation
  * event lifecycle hooks (e.g.: processing, succeeded, failed, etc)

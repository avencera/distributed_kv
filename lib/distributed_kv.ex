defmodule DistributedKV do
  @moduledoc """
  A simple genserver + ets + pg2 that lets you create a distributed kv

  ## Usage

  1. Start one or many instances of the DistributedKV in the supervision tree, ex: 

  ```elixir
  Supervisor.child_spec({DistributedKV.Server, MyApp.Registry},
  id: :myapp_registry
  ),
  ```

  2. Create `MyApp.Registry` and implement functions that handles inserting, dumping and retrieving 


  ```elixir
  defmodule MyApp.Registry do
    @name __MODULE__

    def dump() do
      GenServer.call(@name, :dump)
    end

    def register(key, identifier) do
      GenServer.cast(@name, {:insert, key, identifier})
    end

    def retrieve() do
      case :ets.lookup(@name, key) do
        [{^key, identifier}] -> identifier
        _ -> nil
      end
    end
  end

  ```

  Note: `@name` should be the name you provided in supervision tree (ex: `MyApp.Registry`)
  """
end

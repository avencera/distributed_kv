defmodule DistributedKV.Server do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  ## GenServer ##
  @impl true
  def init(name) do
    :ets.new(name, [:set, :named_table, :public])

    :ok = :pg2.create(name)
    :ok = :pg2.join(name, self())

    refresh(name)

    {:ok, name}
  end

  @impl true
  def handle_cast({:insert, key, value}, name) do
    insert(name, key, value)
    insert_on_other_nodes(name, key, value)

    {:noreply, name}
  end

  @impl true
  def handle_info({:replicate, key, value}, name) do
    :ets.insert(name, {key, value})

    {:noreply, name}
  end

  @impl true
  def handle_call(:dump, _from, name) do
    {:reply, :ets.tab2list(name), name}
  end

  def refresh(name) do
    members =
      name
      |> :pg2.get_members()
      |> Enum.filter(fn pid -> pid != self() end)

    if Enum.count(members) > 0 do
      pid = Enum.random(members)

      for {key, value} <- GenServer.call(pid, :dump) do
        :ets.insert(name, {key, value})
      end

      :ok
    else
      :error
    end
  end

  ## PRIVATE API ##
  defp insert(name, key, value) do
    :ets.insert(name, {key, value})
  end

  defp insert_on_other_nodes(name, key, value) do
    for pid <- :pg2.get_members(name), pid != self() do
      send(pid, {:replicate, key, value})
    end
  end
end

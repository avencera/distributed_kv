defmodule DistributedKV.Server do
  use GenServer

  def child_spec(opts) do
    Supervisor.child_spec({DistributedKV.Server, opts[:name]}, id: opts[:name])
  end

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
  def handle_cast({:delete, key}, name) do
    delete(name, key)
    delete_on_other_nodes(name, key)

    {:noreply, name}
  end

  @impl true
  def handle_call(:dump, _from, name) do
    {:reply, :ets.tab2list(name), name}
  end

  def refresh(name) do
    for pid <- :pg2.get_members(name), pid != self() do
      for {key, value} <- GenServer.call(pid, :dump) do
        :ets.insert(name, {key, value})
      end
    end
  end

  ## PRIVATE GEN SERVER API ##
  @impl true
  def handle_info({:replicate_insert, key, value}, name) do
    :ets.insert(name, {key, value})
    {:noreply, name}
  end

  @impl true
  def handle_info({:replicate_delete, key}, name) do
    :ets.delete(name, key)
    {:noreply, name}
  end

  ## PRIVATE API ##
  defp insert(name, key, value) do
    :ets.insert(name, {key, value})
  end

  defp insert_on_other_nodes(name, key, value) do
    for pid <- :pg2.get_members(name), pid != self() do
      send(pid, {:replicate_insert, key, value})
    end
  end

  defp delete(name, key) do
    :ets.delete(name, key)
  end

  defp delete_on_other_nodes(name, key) do
    for pid <- :pg2.get_members(name), pid != self() do
      send(pid, {:replicate_delete, key})
    end
  end
end

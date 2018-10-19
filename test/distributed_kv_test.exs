defmodule DistributedKvTest do
  use ExUnit.Case
  doctest DistributedKv

  test "greets the world" do
    assert DistributedKv.hello() == :world
  end
end

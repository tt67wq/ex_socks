defmodule ClientTest do
  use ExUnit.Case
  doctest Client

  test "greets the world" do
    assert Client.hello() == :world
  end
end

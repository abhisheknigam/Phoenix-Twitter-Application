defmodule Testclient2Test do
  use ExUnit.Case
  doctest Testclient2

  test "greets the world" do
    assert Testclient2.hello() == :world
  end
end

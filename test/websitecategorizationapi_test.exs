defmodule WebsiteCategorizationAPITest do
  use ExUnit.Case

  test "constructs a client" do
    client = WebsiteCategorizationAPI.Client.new("test")
    assert client.api_key == "test"
  end
end

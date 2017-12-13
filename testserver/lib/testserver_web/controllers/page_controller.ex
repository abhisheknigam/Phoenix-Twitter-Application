defmodule TestserverWeb.PageController do
  use TestserverWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end

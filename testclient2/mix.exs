defmodule Testclient2.Mixfile do
  use Mix.Project

  def project do
    [
      app: :testclient2,
      version: "0.1.0",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
	  escript: [main_module: Testclient2],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
		{:phoenixchannelclient, "~> 0.1.0"}
    ]
  end
end

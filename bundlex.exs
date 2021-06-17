defmodule Membrane.Element.Mad.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives(Bundlex.platform())
    ]
  end

  def natives(:linux) do
    [
      inotify: [
        src_base: "inotify",
        sources: ["inotify.c"],
        preprocessor: Unifex,
        interface: :cnode
      ]
    ]
  end
end

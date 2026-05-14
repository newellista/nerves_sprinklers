defmodule NervesSprinklersWeb.CoreComponents do
  use Phoenix.Component

  attr :id, :string, required: true
  attr :flash, :map, required: true
  attr :kind, :atom, values: [:info, :error]
  attr :rest, :global

  def flash(assigns) do
    msg = assigns.flash[Atom.to_string(assigns.kind)]

    assigns =
      assigns
      |> assign(:msg, msg)
      |> assign(:color, if(assigns.kind == :info, do: "bg-blue-50 text-blue-800", else: "bg-red-50 text-red-800"))

    ~H"""
    <div :if={@msg} id={@id} class={"rounded-md p-4 mb-4 #{@color}"} {@rest}>
      <p>{@msg}</p>
    </div>
    """
  end

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div>
      <.flash id="flash-info" kind={:info} flash={@flash} />
      <.flash id="flash-error" kind={:error} flash={@flash} />
    </div>
    """
  end
end

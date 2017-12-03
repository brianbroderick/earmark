defmodule Earmark.Types do

  defmacro __using__(_options \\ []) do
    quote do
      @type token  :: {atom, String.t}
      @type tokens :: list(token)

      @type numbered_line :: %{required(:line) => String.t, required(:lnb) => number, optional(:inside_code) => String.t}

      @type maybe(t) :: t | nil
      @type inline_code_continuation :: {nil | String.t, number}

      @type strings :: list(binary())
    end
  end

end

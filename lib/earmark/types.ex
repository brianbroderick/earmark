defmodule Earmark.Types do

  defmacro __using__(_options \\ []) do
    quote do
      @type token  :: {atom, String.t}
      @type tokens :: list(token)

      @type numbered_line :: %{required(:line) => String.t, required(:lnb) => number, optional(:inside_code) => String.t}

      @type maybe(t) :: t | nil
      @type inline_code_continuation :: {maybe(String.t), number()}

      @type strings :: list(String.t)

      @type elixir_token :: {atom(), String.t}
    end
  end

end

defmodule Earmark.Helpers.YeccHelpers do
  use Earmark.Types

  import Earmark.Helpers.LeexHelpers, only: [lex: 2]

  @doc false
  @spec parse!( String.t, Keyword.t(atom()) ) :: maybe({String.t, String.t})
  def parse!( text, lexer: lexer, parser: parser ) do
    case parse(text, lexer: lexer, parser: parser) do
        {:ok, ast}  -> ast |> elixirize()
        {:error, _} -> nil
    end
  end

  @doc false
  @spec parse( String.t, Keyword.t(atom()) ) ::  {:ok, {charlist(), charlist()}} | {:error, any()}
  def parse( text, lexer: lexer, parser: parser ) do
    with tokens <- lex(text, with: lexer) do
      parser.parse(tokens)
    end
  end

  @spec elixirize( {charlist(), charlist()} ) :: {String.t, String.t} 
  defp elixirize({l, r}), do: { to_string(l), to_string(r) }
end

defmodule Earmark.Helpers.LinkParser do

  import Earmark.Helpers.LeexHelpers, only: [tokenize: 2]
  import Earmark.Helpers.YeccHelpers, only: [parse!: 2]
  import Earmark.Helpers.StringHelpers, only: [behead: 2]

  alias Earmark.Message
  use Earmark.Types

  # Hopfully this will go away in v1.3
  # **********************************
  #
  # Right now it needs to parse the url part of strings according to the following grammar
  #
  #      url -> ( inner_url )
  #      url -> ( inner_url title )
  #
  #      inner_url   -> ( inner_url )
  #      inner_url   -> [ inner_url ]
  #      inner_url   ->  url_char*
  #
  #      url_char -> . - quote - ( - ) - [ - ]
  #
  #      title -> quote .* quote  ;;   not LALR-k here
  #
  #      quote ->  "
  #      quote ->  '              ;;  yep allowing '...." for now
  #
  #      non_quote -> . - quote

  @type t :: maybe({String.t, String.t, String.t, String.t, Message.ts})

  @doc false
  @spec parse_link( String.t, number() ) :: t
  def parse_link( src, lnb ) do
    with {link_text, parsed_text} <- parse!(src, lexer: :link_text_lexer, parser: :link_text_parser),
         beheaded                 <- behead(src, parsed_text),
         tokens                   <- tokenize(beheaded, with: :link_text_lexer) do
       p_url(tokens, lnb) |> make_result(link_text, parsed_text)
     end
  end

  @typep link_tuple :: { strings, strings, maybe(String.t) }
  @typep link_tuple_wo_title :: { strings, strings, nil }
  @typep parsed_tuple :: { String.t, String.t, Message.ts }
  @typep result_tuple :: { strings, strings, maybe(String.t), Message.ts } 


  @spec p_url( list(elixir_token), number() ) :: maybe(result_tuple)
  defp p_url([{:open_paren, _}|ts], lnb), do: url(ts, {[], [], nil}, [:close_paren], lnb)
  defp p_url(_, _), do: nil


  @spec url( list(elixir_token), link_tuple, list(atom()), number() ) :: maybe(result_tuple)
  defp url(tokens, result, needed, lnb)
  # push one level
  defp url([{:open_paren, text}|ts], result, needed, lnb), do: url(ts, add(result, text), [:close_paren|needed], lnb)
  # pop last level
  defp url([{:close_paren, _}|_], result, [:close_paren], _lnb), do: result |> add_empty_messages()
  # pop inner level
  defp url([{:close_paren, text}|ts], result, [:close_paren|needed], lnb), do: url(ts, add(result, text), needed, lnb)
  # A quote on level 0 -> bailing out if there is a matching quote
  defp url(ts_all = [{:open_title, text}|ts], result, [:close_paren], lnb) do
    case bail_out_to_title(ts_all, result, lnb) do
      nil -> url(ts, add(result, text), [:close_paren], lnb)
      res -> res
    end
  end
  # All these are just added to the url
  defp url([{:open_bracket, text}|ts], result, needed, lnb), do: url(ts, add(result, text), needed, lnb)
  defp url([{:close_bracket, text}|ts], result, needed, lnb), do: url(ts, add(result, text), needed, lnb)
  defp url([{:any_quote, text}|ts], result, needed, lnb), do: url(ts, add(result, text), needed, lnb)
  defp url([{:verbatim, text}|ts], result, needed, lnb), do: url(ts, add(result, text), needed, lnb)
  defp url([{:escaped, text}|ts], result, needed, lnb), do: url(ts, add(result, text), needed, lnb)
  # That is not good, actually this is not a legal url part of a link
  defp url(_, _, _, _), do: nil

  @spec bail_out_to_title( list(elixir_token), link_tuple, number() ) :: maybe( result_tuple )
  defp bail_out_to_title(ts, result, lnb) do
    with remaining_text <- ts |> Enum.map(&text_of_token/1) |> Enum.join("") do
      case title(remaining_text, lnb) do
        nil -> nil
        {title_text, inner_title, messages} -> add_title( result, {title_text, inner_title, messages} )
      end
    end
  end

  @spec text_of_token( elixir_token ) :: String.t
  defp text_of_token(token)
  defp text_of_token({:escaped, text}), do: "\\#{text}"
  defp text_of_token({_, text}), do: text

  # sic!!! Greedy and not context aware, matching '..." and "...' for backward comp
  @title_end_rgx ~r{\s+['"](.*)['"](?=\))}

  @spec title( String.t, number() ) :: maybe(parsed_tuple)
  defp title(remaining_text, lnb) do
    case Regex.run(@title_end_rgx, remaining_text) do
      nil             -> nil
      [parsed, inner] -> {parsed, inner, deprecations(parsed, lnb)}
    end
  end

  @spec deprecations( String.t, number() ) :: Message.ts
  defp deprecations(string, lnb) do
   with stripped <- String.trim(string),
        opening  <- String.first(stripped),
        closing  <- String.last(stripped), do: _deprecations(opening, closing, lnb)
  end

  @spec _deprecations( String.t, String.t, number() ) :: Message.ts
  defp _deprecations(opening, closing, _lnb) when opening == closing, do: []
  defp _deprecations(_opening, _closing, lnb) do
    [ {:warning, lnb, "deprecated, mismatching quotes will not be parsed as matching in v1.3"} ]
  end

  @spec make_result( maybe(result_tuple), String.t, String.t ) :: t
  defp make_result(nil, _, _), do: nil
  defp make_result({parsed, url, title, messages}, link_text, "!" <> _) do
    { "![#{link_text}](#{list_to_text(parsed)})", link_text, list_to_text(url), title, messages }
  end
  defp make_result({parsed, url, title, messages}, link_text, _) do
    { "[#{link_text}](#{list_to_text(parsed)})", link_text, list_to_text(url), title, messages }
  end

  @spec add( link_tuple_wo_title, String.t ) :: link_tuple_wo_title
  defp add({parsed_text, url_text, nil}, text), do: {[text|parsed_text], [text|url_text], nil}

  @spec add_title( link_tuple , parsed_tuple ) :: result_tuple
  defp add_title({parsed_text, url_text, _}, {parsed,inner,messages}), do: {[parsed|parsed_text], url_text, inner, messages}

  @spec add_empty_messages( link_tuple ) :: result_tuple
  defp add_empty_messages({f,s,t}), do: {f, s, t, []} 

  @spec list_to_text( list(String.t) ) :: String.t
  defp list_to_text(lst), do: lst |> Enum.reverse() |> Enum.join("")
end

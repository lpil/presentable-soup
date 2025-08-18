-module(presentable_soup_ffi).

-export([sax/3]).

sax(Html, Initial, Fun) ->
    EventFun = fun(Event, _LineNumber, State) ->
        F = fun(E) ->
            case Fun(State, E) of
                {continue, S} -> S;
                {stop, S} -> erlang:throw({soup, S})
            end
        end,
        case Event of
            startDocument -> State;
            endDocument -> State;
            {startPrefixMapping, _Prefix, _Uri} -> State;
            {endPrefixMapping, _Prefix} -> State;
            {ignorableWhitespace, _Content} -> State;
            {processingInstruction, _Target, _Data} -> State;
            {comment, _Content} -> State;
            startCDATA -> State;
            endCDATA -> State;
            {startDTD, _Name, _PublicId, _SystemId} -> State;
            endDTD -> State;
            {startEntity, _SysId} -> State;
            {endEntity, _SysId} -> State;
            {elementDecl, _Name, _Model} -> State;
            {attributeDecl, _ElementName, _AttributeName, _Type, _Mode, _Value} -> State;
            {internalEntityDecl, _Name, _Value} -> State;
            {externalEntityDecl, _Name, _PublicId, _SystemId} -> State;
            {unparsedEntityDecl, _Name, _PublicId, _SystemId, _Ndata} -> State;
            {notationDecl, _Name, _PublicId, _SystemId} -> State;

            {startElement, Uri, LocalName, _QualifiedName, Attributes} ->
                Attributes2 = lists:map(fun convert_attribute/1, Attributes),
                Namespace = convert_namespace(Uri),
                E = {start_element, Namespace, LocalName, Attributes2},
                F(E);

            {endElement, Uri, LocalName, _QualifiedName} ->
                Namespace = convert_namespace(Uri),
                E = {end_element, Namespace, LocalName},
                F(E);

            {characters, _} ->
                F(Event)
        end
    end,
    Options = [{event_fun, EventFun}, {user_state, Initial}, {preserve_ws, true}],
    try htmerl:sax(Html, Options) of
        {ok, S, _Warnings} ->
            {ok, S};
        _ ->
            {error, nil}
    catch
        throw:{soup, S} ->
            {ok, S}
    end.

convert_attribute({_Uri, _Prefix, AttributeName, Value}) ->
    {AttributeName, Value}.

convert_namespace(Uri) ->
    case Uri of
        <<"http://www.w3.org/1999/xhtml">> -> html;
        <<"http://www.w3.org/2000/svg">> -> svg;
        <<"http://www.w3.org/1998/Math/MathML">> -> mathml
    end.

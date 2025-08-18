import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import houdini

@external(erlang, "presentable_soup_ffi", "sax")
fn sax(
  a: String,
  b: state,
  c: fn(state, SaxEvent) -> Next(state),
) -> Result(state, Nil)

type SaxEvent {
  StartElement(
    namespace: Namespace,
    tag: String,
    attributes: List(#(String, String)),
  )
  EndElement(namespace: String, tag: String)
  Characters(String)
}

type Namespace {
  Html
  Svg
  MathMl
}

type Next(state) {
  Stop(state)
  Continue(state)
}

/// A HTML element, queried from a HTML document.
pub type Element {
  /// A HTML element
  Element(
    tag: String,
    attributes: List(#(String, String)),
    children: List(Element),
  )
  /// Some text
  Text(String)
}

/// Convert elements into a pretty-printed HTML string.
///
/// ## Examples
///
/// ```gleam
/// let elements = [
///   soup.Element("h1", [], soup.Text("Hello, Joe! <3"))
/// ]
/// assert soup.elements_to_string(elements)
///   == "<h1>Hello, Joe! &lt;3</h1>"
/// ```
///
pub fn elements_to_string(html: List(Element)) -> String {
  html
  |> list.map(readable("", _, 0))
  |> string.join("\n\n")
}

fn readable(out: String, html: Element, level: Int) -> String {
  case html {
    Text(t) -> {
      let t = case starts_with_whitespace(t), ends_with_whitespace(t) {
        False, False -> t
        True, True -> string.trim(t)
        True, False -> string.trim_start(t)
        False, True -> string.trim_end(t)
      }
      out <> houdini.escape(t)
    }

    // Void elements, these must have no children
    Element(tag: "area" as tag, attributes:, ..)
    | Element(tag: "base" as tag, attributes:, ..)
    | Element(tag: "br" as tag, attributes:, ..)
    | Element(tag: "col" as tag, attributes:, ..)
    | Element(tag: "embed" as tag, attributes:, ..)
    | Element(tag: "hr" as tag, attributes:, ..)
    | Element(tag: "img" as tag, attributes:, ..)
    | Element(tag: "input" as tag, attributes:, ..)
    | Element(tag: "link" as tag, attributes:, ..)
    | Element(tag: "meta" as tag, attributes:, ..)
    | Element(tag: "source" as tag, attributes:, ..)
    | Element(tag: "track" as tag, attributes:, ..)
    | Element(tag: "wbr" as tag, attributes:, ..) -> {
      readable_open(out, tag, attributes)
    }

    // Inner whitespace preserving elements, these must render their text
    // children as-is
    Element(tag: "pre" as tag, attributes:, children: [Text(text)])
    | Element(tag: "textarea" as tag, attributes:, children: [Text(text)])
    | Element(tag: "script" as tag, attributes:, children: [Text(text)])
    | Element(tag: "style" as tag, attributes:, children: [Text(text)]) -> {
      let out = readable_open(out, tag, attributes)
      out <> text <> "</" <> tag <> ">"
    }

    Element(tag:, attributes:, children:) -> {
      let out = readable_open(out, tag, attributes)
      let out = readable_children(out, level + 1, PermitSpace, children)
      out <> "</" <> tag <> ">"
    }
  }
}

fn readable_children(
  out: String,
  level: Int,
  previous: Space,
  nodes: List(Element),
) -> String {
  case nodes {
    [] -> out

    // Final node
    [Text(t) as node] -> {
      case string.trim(t) {
        "" -> out <> "\n" <> string.repeat("  ", level - 1)
        _ -> {
          let out = before_child(out, previous, level, node)
          let out = readable(out, node, level)
          case space_after(node) {
            PermitSpace | ForceSpace ->
              out <> "\n" <> string.repeat("  ", level - 1)
            NoSpace -> out
          }
        }
      }
    }

    // Final node
    [node] -> {
      let out = before_child(out, previous, level, node)
      let out = readable(out, node, level)
      case space_after(node) {
        PermitSpace | ForceSpace ->
          out <> "\n" <> string.repeat("  ", level - 1)
        NoSpace -> out
      }
    }

    // A node with more to follow
    [Text(t) as node, ..nodes] -> {
      case string.trim(t) {
        "" -> readable_children(out, level, ForceSpace, nodes)
        _ -> {
          let out = before_child(out, previous, level, node)
          let out = readable(out, node, level)
          let space = space_after(node)
          readable_children(out, level, space, nodes)
        }
      }
    }

    // A node with more to follow
    [node, ..nodes] -> {
      let out = before_child(out, previous, level, node)
      let out = readable(out, node, level)
      let space = space_after(node)
      readable_children(out, level, space, nodes)
    }
  }
}

fn before_child(
  out: String,
  previous: Space,
  level: Int,
  node: Element,
) -> String {
  case space_before(previous, node) {
    False -> out
    True -> out <> "\n" <> string.repeat("  ", level)
  }
}

type Space {
  NoSpace
  PermitSpace
  ForceSpace
}

fn space_after(node: Element) -> Space {
  case node {
    Text(t) ->
      case ends_with_whitespace(t) {
        True -> ForceSpace
        False -> NoSpace
      }
    Element(..) -> PermitSpace
  }
}

fn ends_with_whitespace(t: String) {
  string.ends_with(t, " ")
  || string.ends_with(t, "\t")
  || string.ends_with(t, "\n")
  || string.ends_with(t, "\r\n")
}

fn starts_with_whitespace(t: String) -> Bool {
  case t {
    " " <> _ | "\n" <> _ | "\t" <> _ | "\r\n" <> _ -> True
    _ -> False
  }
}

fn space_before(previous: Space, node: Element) -> Bool {
  case node {
    Element(..) -> previous != NoSpace
    Text(_) if previous == ForceSpace -> True
    Text(t) -> starts_with_whitespace(t)
  }
}

fn readable_open(
  out: String,
  tag: String,
  attributes: List(#(String, String)),
) -> String {
  let out = out <> "<" <> tag
  let out =
    list.fold(attributes, out, fn(out, attribute) {
      out <> " " <> attribute.0 <> "=\"" <> attribute.1 <> "\""
    })
  out <> ">"
}

fn collect_tree(stack: List(Element), event: SaxEvent) -> List(Element) {
  case event {
    StartElement(tag:, attributes:, ..) -> {
      let element = Element(tag:, attributes:, children: [])
      [element, ..stack]
    }

    EndElement(..) -> {
      case stack {
        [
          Element(tag:, attributes:, children:),
          Element(tag: p_tag, attributes: p_attributes, children: siblings),
          ..stack
        ] -> {
          let element = Element(tag, attributes, list.reverse(children))
          let parent = Element(p_tag, p_attributes, [element, ..siblings])
          [parent, ..stack]
        }

        [Element(tag:, attributes:, children:), ..stack] -> {
          let element = Element(tag, attributes, list.reverse(children))
          [element, ..stack]
        }

        _ -> panic as "EndElement event without StartElement event"
      }
    }

    Characters("") -> stack

    Characters(text) ->
      case stack {
        [Element(tag:, attributes:, children:), ..stack] -> {
          let element = Element(tag, attributes, [Text(text), ..children])
          [element, ..stack]
        }
        _ -> panic as "EndElement event without StartElement event"
      }
  }
}

// Query

/// A query is used to find elements within a HTML document, similar to a CSS
/// selector.
///
/// Run a query on a HTML document with the `find` and `find_all` functions. 
///
pub opaque type Query {
  FindElement(List(Matcher))
  // FindChild(parent: Matcher, child: Query)
  FindDescendant(parent: Query, child: List(Matcher))
}

/// A `Matcher` describes how to match a specific element in an `Element` tree.
/// It might be the element's tag name, a class name, an attribute, or some
/// combination of these.
///
pub opaque type Matcher {
  HasType(namespace: Namespace, tag: String)
  HasAttribute(name: String, value: String)
  HasClass(name: String)
  // Attribute with value starting with a string ([attr^="val"])
  // Attribute with value ending with a string ([attr$="val"])
  // Attribute with value containing a substring ([attr*="val"])
  // Attribute with value equal to or starting with a word ([attr|="val"]) — often used for language codes
  // Attribute with value containing a whole word ([attr~="val"])
  // Pseudo-classes based on state (e.g. :hover, :focus, :checked, :disabled)
  // Pseudo-classes based on position (e.g. :first-child, :last-child, :nth-child(n), :nth-of-type(n))
  // Pseudo-classes based on content (:empty, :has(), :is(), :not())
  // Pseudo-classes based on document structure (:root, :scope)
  // Pseudo-elements (::before, ::after, ::first-line, etc.) — not selectors for elements in the DOM per se, but still matchable targets
  // Combination of selectors (descendant A B, child A > B, adjacent sibling A + B, general sibling A ~ B)
  // // Contains(content: String)
}

/// Find any elements in a view that match the given [`Matcher`](#Matcher).
///
pub fn element(matching matcher: List(Matcher)) -> Query {
  FindElement(matcher)
}

/// Given a `Query` that finds an element, find any of that element's _descendants_
/// that match the given [`Matcher`](#Matcher). This will walk the entire tree
/// from the matching parent.
///
pub fn descendant(of parent: Query, matching matcher: List(Matcher)) -> Query {
  FindDescendant(parent, matcher)
}

/// Matches elements based on their tag name, like `"div"`, `"span"`, or `"a"`.
///
pub fn tag(value: String) -> Matcher {
  HasType(namespace: Html, tag: value)
}

/// Matches SVG elements based on their tag name.
///
pub fn svg(value: String) -> Matcher {
  HasType(namespace: Svg, tag: value)
}

/// Matches MathML elements based on their tag name.
///
pub fn math_ml(value: String) -> Matcher {
  HasType(namespace: MathMl, tag: value)
}

/// Matches elements that have the specified attribute with the given value. If
/// the value is left blank, this matcher will match any element that has the
/// attribute, _regardless of its value_.
///
pub fn attribute(name: String, value: String) -> Matcher {
  HasAttribute(name:, value:)
}

/// Matches elements that include the given space-separated class name(s).
///
/// If you need to match the class attribute exactly, you can use the [`attribute`](#attribute)
/// matcher instead.
///
pub fn class(name: String) -> Matcher {
  HasClass(name)
}

/// Matches an element based on its `id` attribute. Well-formed HTML means that
/// only one element should have a given id.
///
pub fn id(name: String) -> Matcher {
  HasAttribute(name: "id", value: name)
}

/// Matches elements that have the given `data-*` attribute.
///
pub fn data(name: String, value: String) -> Matcher {
  HasAttribute(name: "data-" <> name, value: value)
}

/// It is a common convention to use the `data-test-id` attribute to mark elements
/// for easy querying in tests. This function is a shorthand for writing
/// `query.data("test-id", value)`
///
pub fn test_id(value: String) -> Matcher {
  data("test-id", value)
}

/// Match elements that have the given `aria-*` attribute.
///
pub fn aria(name: String, value: String) -> Matcher {
  HasAttribute(name: "aria-" <> name, value: value)
}

type Finder {
  Finder(
    found: List(Element),
    current: List(Element),
    query: List(List(Matcher)),
    past: List(Option(List(Matcher))),
  )
}

fn query_to_list(query: Query, out: List(List(Matcher))) -> List(List(Matcher)) {
  case query {
    FindDescendant(parent:, child:) -> query_to_list(parent, [child, ..out])
    FindElement(matcher) -> [matcher, ..out]
  }
}

/// Find all elements in a view that matches the given [`Query`](#Query).
///
pub fn find_all(
  in html: String,
  matching query: Query,
) -> Result(List(Element), Nil) {
  let query = query_to_list(query, [])
  let state = Finder(found: [], current: [], query:, past: [])
  sax(html, state, fn(state, event) { Continue(find_elements(state, event)) })
  |> result.map(fn(state) { list.reverse(state.found) })
}

/// Find the first element in a view that matches the given [`Query`](#Query).
///
pub fn find(in html: String, matching query: Query) -> Result(Element, Nil) {
  let query = query_to_list(query, [])
  let state = Finder(found: [], current: [], query:, past: [])
  sax(html, state, fn(state, event) {
    let state = find_elements(state, event)
    case state.found {
      [] -> Continue(state)
      _ -> Stop(state)
    }
  })
  |> result.try(fn(state) { list.first(state.found) })
}

fn find_elements(state: Finder, event: SaxEvent) -> Finder {
  case event {
    Characters(_) -> {
      case state.query {
        [] -> {
          let current = collect_tree(state.current, event)
          Finder(..state, current:)
        }
        _ -> state
      }
    }

    StartElement(namespace:, tag:, attributes:) -> {
      case state.query {
        // We have found a new element that is a descendent of one that matched
        [] -> {
          let current = collect_tree(state.current, event)
          let past = [None, ..state.past]
          Finder(..state, current:, past:)
        }

        [matcher] ->
          // We have found a new element that itself matches
          case does_match(matcher, namespace, tag, attributes) {
            True -> {
              let current = collect_tree(state.current, event)
              let past = [Some(matcher), ..state.past]
              Finder(..state, query: [], past:, current:)
            }
            False -> {
              let past = [None, ..state.past]
              Finder(..state, past:)
            }
          }

        [matcher, ..query] ->
          // We have found a new element that itself matches this first part
          // of the query, but there is yet more to come.
          case does_match(matcher, namespace, tag, attributes) {
            True -> {
              let past = [Some(matcher), ..state.past]
              Finder(..state, query: query, past:)
            }
            False -> {
              let past = [None, ..state.past]
              Finder(..state, past:)
            }
          }
      }
    }

    EndElement(..) -> {
      let current = case state.query {
        [] -> collect_tree(state.current, event)
        _ -> state.current
      }
      case state.past {
        // We are still inside the element that matched the query, continue
        // collecting elements.
        [None, ..past] -> {
          Finder(..state, current:, past:)
        }
        // We have reached the end of the element that matched the query,
        // move it to "found" now that we have collected it and its descendants.
        [Some(matcher), ..past] -> {
          let found = list.append(current, state.found)
          let query = [matcher, ..state.query]
          Finder(current: [], found:, past:, query:)
        }
        [] -> panic as "empty past for end element should not be possible"
      }
    }
  }
}

fn does_match(
  matcher: List(Matcher),
  namespace: Namespace,
  tag: String,
  attributes: List(#(String, String)),
) -> Bool {
  list.all(matcher, fn(matcher) {
    case matcher {
      HasType(namespace: n, tag: t) -> tag == t && namespace == n
      HasAttribute(name:, value:) -> has_attribute(name, value, attributes)
      HasClass(name:) -> {
        let desired =
          name |> string.split(" ") |> list.filter(fn(n) { n != "" })
        list.any(attributes, fn(attribute) {
          list.all(desired, fn(name) {
            attribute.0 == "class"
            && {
              attribute.1 == name
              || string.starts_with(attribute.1, name <> " ")
              || string.ends_with(attribute.1, " " <> name)
              || string.contains(attribute.1, " " <> name <> " ")
            }
          })
        })
      }
    }
  })
}

fn has_attribute(
  name: String,
  value: String,
  attributes: List(#(String, String)),
) -> Bool {
  list.any(attributes, fn(attr) {
    name == attr.0 && { value == "" || value == attr.1 }
  })
}

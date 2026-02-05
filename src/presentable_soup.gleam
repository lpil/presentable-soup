import gleam/list
import gleam/option
import gleam/string
import houdini

//
// This code came to me in a dream.
//

pub type Namespace {
  Html
  Svg
  MathMl
}

type SaxEvent {
  StartElement(
    namespace: Namespace,
    tag: String,
    attributes: List(#(String, String)),
  )
  EndElement(namespace: String, tag: String)
  Characters(String)
  End
}

/// A representation of a HTML document or fragment.
pub type ElementTree {
  /// A HTML element
  ElementNode(
    tag: String,
    attributes: List(#(String, String)),
    children: List(ElementTree),
  )
  /// Some text
  TextNode(String)
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
pub fn elements_to_string(html: List(ElementTree)) -> String {
  html
  |> list.map(readable("", _, 0))
  |> string.join("\n\n")
}

fn readable(out: String, html: ElementTree, level: Int) -> String {
  case html {
    TextNode(t) -> {
      let t = case starts_with_whitespace(t), ends_with_whitespace(t) {
        False, False -> t
        True, True -> string.trim(t)
        True, False -> string.trim_start(t)
        False, True -> string.trim_end(t)
      }
      out <> houdini.escape(t)
    }

    // Void elements, these must have no children
    ElementNode(tag: "area" as tag, attributes:, ..)
    | ElementNode(tag: "base" as tag, attributes:, ..)
    | ElementNode(tag: "br" as tag, attributes:, ..)
    | ElementNode(tag: "col" as tag, attributes:, ..)
    | ElementNode(tag: "embed" as tag, attributes:, ..)
    | ElementNode(tag: "hr" as tag, attributes:, ..)
    | ElementNode(tag: "img" as tag, attributes:, ..)
    | ElementNode(tag: "input" as tag, attributes:, ..)
    | ElementNode(tag: "link" as tag, attributes:, ..)
    | ElementNode(tag: "meta" as tag, attributes:, ..)
    | ElementNode(tag: "source" as tag, attributes:, ..)
    | ElementNode(tag: "track" as tag, attributes:, ..)
    | ElementNode(tag: "wbr" as tag, attributes:, ..) -> {
      readable_open(out, tag, attributes)
    }

    // Inner whitespace preserving elements, these must render their text
    // children as-is
    ElementNode(tag: "pre" as tag, attributes:, children: [TextNode(text)])
    | ElementNode(
        tag: "textarea" as tag,
        attributes:,
        children: [TextNode(text)],
      )
    | ElementNode(tag: "script" as tag, attributes:, children: [TextNode(text)])
    | ElementNode(tag: "style" as tag, attributes:, children: [TextNode(text)]) -> {
      let out = readable_open(out, tag, attributes)
      out <> text <> "</" <> tag <> ">"
    }

    ElementNode(tag:, attributes:, children:) -> {
      let out = readable_open(out, tag, attributes)
      let out = readable_children(out, level + 1, PermitSpace, children)
      out <> "</" <> tag <> ">"
    }
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

type Space {
  NoSpace
  PermitSpace
  ForceSpace
}

fn space_after(node: ElementTree) -> Space {
  case node {
    TextNode(t) ->
      case ends_with_whitespace(t) {
        True -> ForceSpace
        False -> NoSpace
      }
    ElementNode(..) -> PermitSpace
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

fn space_before(previous: Space, node: ElementTree) -> Bool {
  case node {
    ElementNode(..) -> previous != NoSpace
    TextNode(_) if previous == ForceSpace -> True
    TextNode(t) -> starts_with_whitespace(t)
  }
}

fn readable_children(
  out: String,
  level: Int,
  previous: Space,
  nodes: List(ElementTree),
) -> String {
  case nodes {
    [] -> out

    // Final node
    [TextNode(t) as node] -> {
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
    [TextNode(t) as node, ..nodes] -> {
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
  node: ElementTree,
) -> String {
  case space_before(previous, node) {
    False -> out
    True -> out <> "\n" <> string.repeat("  ", level)
  }
}

pub type Error {
  ParsingFailed
  NoContentMatched
}

@external(erlang, "presentable_soup_ffi", "sax")
fn sax(
  a: String,
  b: state,
  c: fn(state, SaxEvent) -> state,
) -> Result(state, Nil)

pub fn scrape(scraper: Scraper(out), html: String) -> Result(out, Error) {
  case sax(html, scraper, apply) {
    Ok(More(f)) -> {
      case f(End) {
        Done(value) -> Ok(value)
        Fail | More(_) -> Error(NoContentMatched)
      }
    }
    Ok(Done(value)) -> Ok(value)
    Ok(Fail) -> Error(NoContentMatched)
    Error(_) -> Error(ParsingFailed)
  }
}

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

pub fn find_one(
  matching matchers: List(Matcher),
  scrape scraper: Scraper(t),
) -> Scraper(t) {
  More(fn(event) {
    case event {
      StartElement(n, t, a) ->
        case does_match(matchers, n, t, a) {
          True -> apply(take_one(0, scraper), event)
          False -> find_one(matchers, scraper)
        }
      EndElement(..) | Characters(_) -> find_one(matchers, scraper)
      End -> Fail
    }
  })
}

pub fn find_all(
  matching matchers: List(Matcher),
  scrape scraper: Scraper(t),
) -> Scraper(List(t)) {
  find_all_scraper([], matchers, scraper)
}

fn find_all_scraper(
  acc: List(t),
  matchers: List(Matcher),
  scraper: Scraper(t),
) -> Scraper(List(t)) {
  More(fn(event) {
    echo #(acc, event)
    case event {
      StartElement(n, t, a) ->
        case does_match(matchers, n, t, a) {
          True -> {
            let self = fn(next) {
              let acc = case next {
                option.None -> acc
                option.Some(v) -> [v, ..acc]
              }
              find_all_scraper(acc, matchers, scraper)
            }
            take_one_then_continue(0, scraper, self)
            |> apply(event)
          }
          False -> find_all_scraper(acc, matchers, scraper)
        }
      EndElement(..) | Characters(_) -> find_all_scraper(acc, matchers, scraper)
      End -> Done(list.reverse(acc))
    }
  })
}

fn take_one(depth: Int, scraper: Scraper(t)) -> Scraper(t) {
  More(fn(event) {
    case event {
      StartElement(..) -> take_one(depth + 1, apply(scraper, event))
      EndElement(..) if depth <= 1 -> apply(scraper, End)
      EndElement(..) -> take_one(depth - 1, apply(scraper, event))
      Characters(..) -> take_one(depth, apply(scraper, event))
      End -> apply(scraper, End)
    }
  })
}

fn take_one_then_continue(
  depth: Int,
  scraper: Scraper(t1),
  continuer: fn(option.Option(t1)) -> Scraper(t2),
) -> Scraper(t2) {
  More(fn(event) {
    case event {
      StartElement(..) ->
        take_one_then_continue(depth + 1, apply(scraper, event), continuer)
      EndElement(..) if depth > 1 -> {
        take_one_then_continue(depth - 1, apply(scraper, event), continuer)
      }
      Characters(..) ->
        take_one_then_continue(depth, apply(scraper, event), continuer)

      End | EndElement(..) ->
        case apply(scraper, End) {
          Done(v) -> continuer(option.Some(v))
          Fail | More(_) -> continuer(option.None)
        }
        |> apply(End)
    }
  })
}

fn apply(scraper: Scraper(t), event: SaxEvent) -> Scraper(t) {
  case scraper {
    More(f) -> f(event)
    Done(_) | Fail -> scraper
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

pub opaque type Scraper(value) {
  Scraper(next: fn(SaxEvent) -> Scraper(value), end: fn() -> Result(value, Nil))
}

fn done(end: fn() -> Result(t, Nil)) -> Scraper(t) {
  Scraper(next: fn(_) { done(end) }, end:)
}

fn fail() {
  Scraper(next: fn(_) { fail() }, end: fn() { Error(Nil) })
}

fn fresh(next: fn(SaxEvent) -> Scraper(t)) -> Scraper(t) {
  Scraper(next:, end: fn() { Error(Nil) })
}

pub fn get_tree() -> Scraper(ElementTree) {
  fresh(tree_scraper_fn([]))
}

fn tree_scraper_fn(
  stack: List(ElementTree),
) -> fn(SaxEvent) -> Scraper(ElementTree) {
  fn(event) {
    case event {
      End ->
        case stack {
          [] -> fail()
          [TextNode(_) as element] -> done(fn() { Ok(element) })
          [ElementNode(tag, attributes, children)] ->
            done(fn() {
              Ok(ElementNode(tag, attributes, list.reverse(children)))
            })
          _ -> panic as "Too many elements, failed"
        }

      StartElement(tag:, attributes:, ..) -> {
        let element = ElementNode(tag:, attributes:, children: [])
        fresh(tree_scraper_fn([element, ..stack]))
      }

      EndElement(..) -> {
        case stack {
          [
            ElementNode(tag:, attributes:, children:),
            ElementNode(
              tag: p_tag,
              attributes: p_attributes,
              children: siblings,
            ),
            ..stack
          ] -> {
            let element = ElementNode(tag, attributes, list.reverse(children))
            let parent = ElementNode(p_tag, p_attributes, [element, ..siblings])
            fresh(tree_scraper_fn([parent, ..stack]))
          }

          [ElementNode(tag:, attributes:, children:), ..stack] -> {
            let element = ElementNode(tag, attributes, list.reverse(children))
            fresh(tree_scraper_fn([element, ..stack]))
          }

          _ -> panic as "EndElement event without StartElement event"
        }
      }

      Characters("") -> fresh(tree_scraper_fn(stack))

      Characters(text) ->
        case stack {
          [ElementNode(tag:, attributes:, children:), ..stack] -> {
            let element =
              ElementNode(tag, attributes, [TextNode(text), ..children])
            fresh(tree_scraper_fn([element, ..stack]))
          }
          _ -> panic as "Characters event without StartElement event"
        }
    }
  }
}

pub fn get_text() -> Scraper(List(String)) {
  fresh(text_scraper_fn([]))
}

fn text_scraper_fn(acc: List(String)) -> fn(SaxEvent) -> Scraper(List(String)) {
  fn(event) {
    case event {
      Characters(string) -> fresh(text_scraper_fn([string, ..acc]))
      StartElement(..) | EndElement(..) -> fresh(text_scraper_fn(acc))
      End -> done(fn() { Ok(list.reverse(acc)) })
    }
  }
}

pub fn get_tag() -> Scraper(String) {
  fresh(tag_scraper_fn())
}

fn tag_scraper_fn() -> fn(SaxEvent) -> Scraper(String) {
  fn(event) {
    case event {
      StartElement(tag:, ..) -> done(fn() { Ok(tag) })
      EndElement(..) | Characters(_) | End -> fresh(tag_scraper_fn())
    }
  }
}

pub fn get_namespace() -> Scraper(Namespace) {
  fresh(namespace_scraper_fn())
}

fn namespace_scraper_fn() -> fn(SaxEvent) -> Scraper(Namespace) {
  fn(event) {
    case event {
      StartElement(namespace:, ..) -> done(fn() { Ok(namespace) })
      EndElement(..) | Characters(_) | End -> fresh(namespace_scraper_fn())
    }
  }
}

pub fn get_attributes() -> Scraper(List(#(String, String))) {
  fresh(attributes_scraper_fn())
}

fn attributes_scraper_fn() -> fn(SaxEvent) -> Scraper(List(#(String, String))) {
  fn(event) {
    case event {
      StartElement(attributes:, ..) -> done(fn() { Ok(attributes) })
      EndElement(..) | Characters(_) | End -> fresh(attributes_scraper_fn())
    }
  }
}

pub fn map(scraper: Scraper(a), transform: fn(a) -> b) -> Scraper(b) {
  Scraper(next: fn(event) { map(scraper, transform).next(event) }, end: fn() {
    case scraper.end() {
      Ok(value) -> Ok(transform(value))
      Error(error) -> Error(error)
    }
  })
}

pub fn map2(
  scraper1: Scraper(t1),
  scraper2: Scraper(t2),
  transform: fn(t1, t2) -> out,
) -> Scraper(out) {
  More(fn(event) {
    case scraper1, scraper2 {
      Fail, _ | _, Fail -> Fail
      More(f1), More(f2) -> map2(f1(event), f2(event), transform)
      More(f1), Done(_) -> map2(f1(event), scraper2, transform)
      Done(_), More(f2) -> map2(scraper1, f2(event), transform)
      Done(v1), Done(v2) -> Done(transform(v1, v2))
    }
  })
}

pub fn map3(
  scraper0: Scraper(t0),
  scraper1: Scraper(t1),
  scraper2: Scraper(t2),
  transform: fn(t0, t1, t2) -> out,
) -> Scraper(out) {
  map2(scraper0, scraper1, fn(v0, v1) { #(v0, v1) })
  |> map2(scraper2, fn(v, v2) { transform(v.0, v.1, v2) })
}

pub fn map4(
  scraper0: Scraper(t0),
  scraper1: Scraper(t1),
  scraper2: Scraper(t2),
  scraper3: Scraper(t3),
  transform: fn(t0, t1, t2, t3) -> out,
) -> Scraper(out) {
  map3(scraper0, scraper1, scraper2, fn(v0, v1, v2) { #(v0, v1, v2) })
  |> map2(scraper3, fn(v, v3) { transform(v.0, v.1, v.2, v3) })
}

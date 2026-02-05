import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import houdini

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

/// A scraper matches elements and extracts data from them.
pub opaque type Scraper(value) {
  // This code came to me in a dream.
  Scraper(next: fn(SaxEvent) -> Scraper(value), end: fn() -> Option(value))
}

/// Queries are used to scope scrapers to specific elements.
pub opaque type Query(in, out) {
  Query(make_scraper: fn(Scraper(in)) -> Scraper(out))
}

/// Start a query to find the first element matching the given matchers.
///
/// Chain with `descendant` to narrow down the search, then finish with `return`
/// to specify what data to extract.
///
pub fn element(matchers: List(Matcher)) -> Query(value, value) {
  Query(fn(scraper) { find_one(matchers, scraper) })
}

/// Start a query to find all elements matching the given matchers.
///
/// This is not recursive, so if you search for `div` elements it won't match
/// any `div`s that are children of other matched `div`s.
///
pub fn elements(matchers: List(Matcher)) -> Query(value, List(value)) {
  Query(fn(scraper) { find_all(matchers, scraper) })
}

/// Narrow a query to find the first descendant matching the given matchers.
///
pub fn descendant(
  query: Query(in, out),
  matchers: List(Matcher),
) -> Query(in, out) {
  Query(fn(scraper) { query.make_scraper(find_one(matchers, scraper)) })
}

/// Narrow a query to find all descendants matching the given matchers.
///
pub fn descendants(
  query: Query(List(in), out),
  matchers: List(Matcher),
) -> Query(in, out) {
  Query(fn(scraper) { query.make_scraper(find_all(matchers, scraper)) })
}

/// Finish a query by specifying what data to extract from matched elements.
///
pub fn return(query: Query(in, out), scraper: Scraper(in)) -> Scraper(out) {
  query.make_scraper(scraper)
}

/// Errors that can occur when scraping HTML.
pub type ScrapeError {
  /// The HTML document was malformed in a way that make it unparsable.
  ParsingFailed
  /// The document did not have the structure the scraper expected, so it was
  /// unable to extract the desired data.
  ScrapingFailed
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

@external(erlang, "presentable_soup_ffi", "sax")
fn sax(
  a: String,
  b: state,
  c: fn(state, SaxEvent) -> state,
) -> Result(state, Nil)

/// Run a scraper, returning the scraped data, or an error if the scraper
/// failed to find its data.
///
pub fn scrape(scraper: Scraper(out), html: String) -> Result(out, ScrapeError) {
  case sax(html, scraper, fn(scraper, event) { scraper.next(event) }) {
    Ok(scraper) ->
      case scraper.end() {
        Some(data) -> Ok(data)
        None -> Error(ScrapingFailed)
      }
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

fn find_one(matchers: List(Matcher), scraper: Scraper(t)) -> Scraper(t) {
  Scraper(
    next: fn(event) {
      case event {
        StartElement(n, t, a) ->
          case does_match(matchers, n, t, a) {
            True -> take_one(0, scraper).next(event)
            False -> find_one(matchers, scraper)
          }
        EndElement(..) | Characters(_) -> find_one(matchers, scraper)
        End -> fail()
      }
    },
    end: fn() { None },
  )
}

/// Find all elements that matches the given matchers.
///
/// This is not recursive, so if you search for `div` elements it won't match
/// any `div`s that are children of other `div`s.
///
fn find_all(matchers: List(Matcher), scraper: Scraper(t)) -> Scraper(List(t)) {
  find_all_scraper([], matchers, scraper)
}

fn find_all_scraper(
  acc: List(t),
  matchers: List(Matcher),
  scraper: Scraper(t),
) -> Scraper(List(t)) {
  Scraper(
    next: fn(event) {
      case event {
        StartElement(n, t, a) ->
          case does_match(matchers, n, t, a) {
            True -> {
              let self = fn(next) {
                let acc = case next {
                  None -> acc
                  Some(v) -> [v, ..acc]
                }
                find_all_scraper(acc, matchers, scraper)
              }
              take_one_then_continue(0, scraper, self).next(event)
            }
            False -> find_all_scraper(acc, matchers, scraper)
          }
        EndElement(..) | Characters(_) ->
          find_all_scraper(acc, matchers, scraper)
        End -> done(list.reverse(acc))
      }
    },
    end: fn() { Some(list.reverse(acc)) },
  )
}

fn take_one(depth: Int, scraper: Scraper(t)) -> Scraper(t) {
  Scraper(
    next: fn(event) {
      case event {
        StartElement(..) -> take_one(depth + 1, scraper.next(event))
        EndElement(..) if depth <= 1 -> scraper.next(End)
        EndElement(..) -> take_one(depth - 1, scraper.next(event))
        Characters(..) -> take_one(depth, scraper.next(event))
        End -> scraper.next(End)
      }
    },
    end: fn() { None },
  )
}

fn take_one_then_continue(
  depth: Int,
  scraper: Scraper(t1),
  continuer: fn(Option(t1)) -> Scraper(t2),
) -> Scraper(t2) {
  Scraper(
    next: fn(event) {
      case event {
        StartElement(..) ->
          take_one_then_continue(depth + 1, scraper.next(event), continuer)
        EndElement(..) if depth > 1 ->
          take_one_then_continue(depth - 1, scraper.next(event), continuer)
        Characters(..) ->
          take_one_then_continue(depth, scraper.next(event), continuer)
        EndElement(..) -> {
          let final_scraper = scraper.next(End)
          continuer(final_scraper.end())
        }
        End -> {
          let final_scraper = scraper.next(End)
          continuer(final_scraper.end()).next(End)
        }
      }
    },
    end: fn() { None },
  )
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
pub fn with_tag(value: String) -> Matcher {
  HasType(namespace: Html, tag: value)
}

/// Matches SVG elements based on their tag name.
///
pub fn with_svg_tag(value: String) -> Matcher {
  HasType(namespace: Svg, tag: value)
}

/// Matches MathML elements based on their tag name.
///
pub fn with_math_ml_tag(value: String) -> Matcher {
  HasType(namespace: MathMl, tag: value)
}

/// Matches elements that have the specified attribute with the given value. If
/// the value is left blank, this matcher will match any element that has the
/// attribute, _regardless of its value_.
///
pub fn with_attribute(name: String, value: String) -> Matcher {
  HasAttribute(name:, value:)
}

/// Matches elements that include the given space-separated class name(s).
///
/// If you need to match the class attribute exactly, you can use the [`attribute`](#attribute)
/// matcher instead.
///
pub fn with_class(name: String) -> Matcher {
  HasClass(name)
}

/// Matches an element based on its `id` attribute. Well-formed HTML means that
/// only one element should have a given id.
///
pub fn with_id(name: String) -> Matcher {
  HasAttribute(name: "id", value: name)
}

/// Matches elements that have the given `data-*` attribute.
///
pub fn with_data(name: String, value: String) -> Matcher {
  HasAttribute(name: "data-" <> name, value: value)
}

/// It is a common convention to use the `data-test-id` attribute to mark elements
/// for easy querying in tests. This function is a shorthand for writing
/// `query.data("test-id", value)`
///
pub fn with_test_id(value: String) -> Matcher {
  with_data("test-id", value)
}

/// Match elements that have the given `aria-*` attribute.
///
pub fn with_aria(name: String, value: String) -> Matcher {
  HasAttribute(name: "aria-" <> name, value: value)
}

fn done(value: t) -> Scraper(t) {
  Scraper(next: fn(_) { done(value) }, end: fn() { Some(value) })
}

fn fail() -> Scraper(t) {
  Scraper(next: fn(_) { fail() }, end: fn() { None })
}

fn fresh(next: fn(SaxEvent) -> Scraper(t)) -> Scraper(t) {
  Scraper(next:, end: fn() { None })
}

/// Get the element add its descendants as an `ElementTree`. This may be useful
/// for snapshot testing when combined with `elements_to_string`.
///
pub fn element_tree() -> Scraper(ElementTree) {
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
          [TextNode(_) as element] -> done(element)
          [ElementNode(tag, attributes, children)] ->
            done(ElementNode(tag, attributes, list.reverse(children)))
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

/// Get all the text contained by the element and its descendants.
///
pub fn text_content() -> Scraper(List(String)) {
  fresh(text_scraper_fn([]))
}

fn text_scraper_fn(acc: List(String)) -> fn(SaxEvent) -> Scraper(List(String)) {
  fn(event) {
    case event {
      Characters(string) -> fresh(text_scraper_fn([string, ..acc]))
      StartElement(..) | EndElement(..) -> fresh(text_scraper_fn(acc))
      End -> done(list.reverse(acc))
    }
  }
}

/// Get the tag of the element.
///
pub fn tag() -> Scraper(String) {
  fresh(tag_scraper_fn())
}

fn tag_scraper_fn() -> fn(SaxEvent) -> Scraper(String) {
  fn(event) {
    case event {
      StartElement(tag:, ..) -> done(tag)
      EndElement(..) | Characters(_) | End -> fresh(tag_scraper_fn())
    }
  }
}

/// Get the namespace of the element.
///
pub fn namespace() -> Scraper(Namespace) {
  fresh(namespace_scraper_fn())
}

fn namespace_scraper_fn() -> fn(SaxEvent) -> Scraper(Namespace) {
  fn(event) {
    case event {
      StartElement(namespace:, ..) -> done(namespace)
      EndElement(..) | Characters(_) | End -> fresh(namespace_scraper_fn())
    }
  }
}

/// Get the attributes of the element.
///
pub fn attributes() -> Scraper(List(#(String, String))) {
  fresh(attributes_scraper_fn())
}

fn attributes_scraper_fn() -> fn(SaxEvent) -> Scraper(List(#(String, String))) {
  fn(event) {
    case event {
      StartElement(attributes:, ..) -> done(attributes)
      EndElement(..) | Characters(_) | End -> fresh(attributes_scraper_fn())
    }
  }
}

/// Transform the data returned by a scraper by running a function on it after
/// it has been extracted from the HTML.
///
pub fn map(scraper: Scraper(a), transform: fn(a) -> b) -> Scraper(b) {
  Scraper(next: fn(event) { map(scraper.next(event), transform) }, end: fn() {
    case scraper.end() {
      Some(value) -> Some(transform(value))
      None -> None
    }
  })
}

/// Transform the data returned by a scraper by running a function on it after
/// it has been extracted from the HTML.
///
/// If the transformer returns an error then the scraper returns nothing.
///
pub fn try_map(
  scraper: Scraper(a),
  transform: fn(a) -> Result(b, error),
) -> Scraper(b) {
  Scraper(
    next: fn(event) { try_map(scraper.next(event), transform) },
    end: fn() {
      case scraper.end() {
        Some(value) -> transform(value) |> option.from_result
        None -> None
      }
    },
  )
}

/// Take two scrapers and combine them into one. The final result from both is
/// combined using a function to make the new final result.
///
pub fn merge2(
  scraper1: Scraper(t1),
  scraper2: Scraper(t2),
  transform: fn(t1, t2) -> out,
) -> Scraper(out) {
  Scraper(
    next: fn(event) {
      merge2(scraper1.next(event), scraper2.next(event), transform)
    },
    end: fn() {
      case scraper1.end() {
        Some(value1) ->
          case scraper2.end() {
            Some(value2) -> Some(transform(value1, value2))
            _ -> None
          }
        _ -> None
      }
    },
  )
}

/// Take three scrapers and combine them into one. The final result from each
/// is combined using a function to make the new final result.
///
pub fn merge3(
  scraper0: Scraper(t0),
  scraper1: Scraper(t1),
  scraper2: Scraper(t2),
  transform: fn(t0, t1, t2) -> out,
) -> Scraper(out) {
  Scraper(
    next: fn(event) {
      merge3(
        scraper0.next(event),
        scraper1.next(event),
        scraper2.next(event),
        transform,
      )
    },
    end: fn() {
      case scraper0.end() {
        Some(value0) ->
          case scraper1.end() {
            Some(value1) ->
              case scraper2.end() {
                Some(value2) -> Some(transform(value0, value1, value2))
                _ -> None
              }
            _ -> None
          }
        _ -> None
      }
    },
  )
}

/// Take four scrapers and combine them into one. The final result from each
/// is combined using a function to make the new final result.
///
pub fn merge4(
  scraper0: Scraper(t0),
  scraper1: Scraper(t1),
  scraper2: Scraper(t2),
  scraper3: Scraper(t3),
  transform: fn(t0, t1, t2, t3) -> out,
) -> Scraper(out) {
  Scraper(
    next: fn(event) {
      merge4(
        scraper0.next(event),
        scraper1.next(event),
        scraper2.next(event),
        scraper3.next(event),
        transform,
      )
    },
    end: fn() {
      case scraper0.end() {
        Some(value0) ->
          case scraper1.end() {
            Some(value1) ->
              case scraper2.end() {
                Some(value2) ->
                  case scraper3.end() {
                    Some(value3) ->
                      Some(transform(value0, value1, value2, value3))
                    _ -> None
                  }
                _ -> None
              }
            _ -> None
          }
        _ -> None
      }
    },
  )
}

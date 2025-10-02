import gleam/list
import gleam/string

// --- TESTING ----------------------------------

pub fn main() {
  let _ = find_one([class("wibble")], get_text())

  let _ =
    map2(get_tag(), get_text(), fn(tag, text) {
      "element " <> tag <> ": " <> string.join(text, " ")
    })
}

// --- IMPLEMENTATION ---------------------------

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
          True -> scrape_one(0, scraper)
          False -> find_one(matchers, scraper)
        }
      EndElement(..) | Characters(_) -> find_one(matchers, scraper)
      End -> Fail
    }
  })
}

fn scrape_one(depth: Int, scraper: Scraper(t)) -> Scraper(t) {
  More(fn(event) {
    case event {
      StartElement(..) -> scrape_one(depth + 1, apply(scraper, event))
      EndElement(..) if depth <= 0 -> apply(scraper, End)
      EndElement(..) -> scrape_one(depth - 1, apply(scraper, event))
      Characters(..) -> scrape_one(depth, apply(scraper, event))
      End -> apply(scraper, End)
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
  More(fn(SaxEvent) -> Scraper(value))
  Done(value)
  Fail
}

pub fn get_text() -> Scraper(List(String)) {
  text_scraper([])
}

fn text_scraper(acc: List(String)) -> Scraper(List(String)) {
  More(fn(event) {
    case event {
      Characters(string) -> text_scraper([string, ..acc])
      StartElement(..) | EndElement(..) -> text_scraper(acc)
      End -> Done(list.reverse(acc))
    }
  })
}

pub fn get_tag() -> Scraper(String) {
  More(fn(event) {
    case event {
      End -> Fail
      EndElement(..) | Characters(_) -> get_tag()
      StartElement(tag:, ..) -> Done(tag)
    }
  })
}

pub fn get_namespace() -> Scraper(Namespace) {
  More(fn(event) {
    case event {
      End -> Fail
      EndElement(..) | Characters(_) -> get_namespace()
      StartElement(namespace:, ..) -> Done(namespace)
    }
  })
}

pub fn get_attributes(
  extract: fn(List(#(String, String))) -> value,
) -> Scraper(value) {
  More(fn(event) {
    case event {
      End -> Fail
      EndElement(..) | Characters(_) -> get_attributes(extract)
      StartElement(attributes:, ..) -> Done(extract(attributes))
    }
  })
}

pub fn map(scraper: Scraper(a), transform: fn(a) -> b) -> Scraper(b) {
  More(fn(event) {
    case scraper {
      More(scrape) -> map(scrape(event), transform)
      Fail -> Fail
      Done(scraped) -> Done(transform(scraped))
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

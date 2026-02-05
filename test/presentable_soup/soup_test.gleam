import birdie
import gleam/list
import gleam/string
import presentable_soup as soup

fn format_snap(input: String, description: String, output: String) -> String {
  "Input:\n"
  <> string.trim(input)
  <> "\n\nScraper:\n"
  <> description
  <> "\n\nOutput:\n"
  <> output
}

pub fn element_to_string_preserve_whitespace_element_test() {
  [
    soup.ElementNode("div", [], [
      soup.ElementNode("script", [], [
        soup.TextNode(
          "function main() {
  console.log(1);
}

main();",
        ),
      ]),
    ]),
  ]
  |> soup.elements_to_string
  |> birdie.snap(
    "script tags don't have their inner content padded or indented",
  )
}

pub fn element_to_string_no_whitespace_text_test() {
  [
    soup.ElementNode("h1", [], [soup.TextNode("Hello, Joe!")]),
  ]
  |> soup.elements_to_string
  |> birdie.snap("text nodes without space around do not gain space")
}

pub fn element_to_string_whitespace_before_text_test() {
  [
    soup.ElementNode("h1", [], [soup.TextNode(" space")]),
  ]
  |> soup.elements_to_string
  |> birdie.snap("text nodes can have whitespace before")
}

pub fn element_to_string_whitespace_after_text_test() {
  [
    soup.ElementNode("h1", [], [soup.TextNode("space ")]),
  ]
  |> soup.elements_to_string
  |> birdie.snap("text nodes can have whitespace after")
}

pub fn element_to_string_whitespace_between_text_test() {
  [
    soup.ElementNode("h1", [], [
      soup.TextNode("one "),
      soup.ElementNode("span", [], [soup.TextNode("two")]),
      soup.TextNode("three "),
      soup.ElementNode("span", [], [soup.TextNode(" four ")]),
      soup.TextNode(" five"),
    ]),
  ]
  |> soup.elements_to_string
  |> birdie.snap("text nodes can have whitespace between when safe")
}

pub fn scrape_0_test() {
  let page =
    "
<header>
  <h1>Lustre Labs</h1>
  Woop!
</header>
    "

  let assert Ok(element) =
    soup.find_one([soup.tag("h1")], soup.get_tree())
    |> soup.scrape(page)

  [element]
  |> soup.elements_to_string
  |> format_snap(page, "find_one h1 tag, get tree", _)
  |> birdie.snap("scrape_0_test")
}

pub fn scrape_1_test() {
  let page =
    "
<header>
  <h1>
    <br class=1>
    <br class=2>
  </h1>
</header>
    "

  let assert Ok(element) =
    soup.find_one([soup.tag("h1")], soup.get_tree())
    |> soup.scrape(page)

  [element]
  |> soup.elements_to_string
  |> format_snap(page, "find_one h1 tag, get tree", _)
  |> birdie.snap("scrape_1_test")
}

pub fn scrape_2_test() {
  let page =
    "
<header>
  <p>one</p>
  <p>two</p>
</header>
    "

  let assert Ok(element) =
    soup.find_all([soup.tag("p")], soup.get_tree())
    |> soup.scrape(page)

  element
  |> soup.elements_to_string
  |> format_snap(page, "find_all p tags, get tree for each", _)
  |> birdie.snap("scrape_2_test")
}

pub fn scrape_3_test() {
  let page =
    "
<header>
  <p>one</p>
  <p>two</p>
  <div>
    <p>three</p>
    <p>four</p>
  </div>
</header>
    "

  let assert Ok(element) =
    soup.find_all([soup.tag("p")], soup.get_tree())
    |> soup.scrape(page)

  element
  |> soup.elements_to_string
  |> format_snap(
    page,
    "find_all p tags (including nested), get tree for each",
    _,
  )
  |> birdie.snap("scrape_3_test")
}

pub fn scrape_4_test() {
  let page =
    "
<header>
  <p>zero</p>
  <p><span>one</span></p>
  <p><span>two</span></p>
  <div>
    <p><span>three</span></p>
    <p><span>four</span></p>
    <p>five</p>
  </div>
</header>
    "

  let assert Ok(element) =
    soup.find_all(
      [soup.tag("p")],
      soup.find_one([soup.tag("span")], soup.get_tree()),
    )
    |> soup.scrape(page)

  element
  |> soup.elements_to_string
  |> format_snap(
    page,
    "find_all p tags, then find_one span inside each, get tree (skips p without span)",
    _,
  )
  |> birdie.snap("scrape_4_test")
}

pub fn scrape_5_test() {
  let page =
    "
<p><span>one</span><span><span>two</span></span><span>three</span></p>
    "

  let assert Ok(element) =
    soup.find_all(
      [soup.tag("p")],
      soup.find_all([soup.tag("span")], soup.get_tree()),
    )
    |> soup.map(list.flatten)
    |> soup.scrape(page)

  element
  |> soup.elements_to_string
  |> format_snap(
    page,
    "find_all p tags, find_all spans inside each, flatten results",
    _,
  )
  |> birdie.snap("scrape_5_test")
}

pub fn get_tag_test() {
  let page = "<div><span>hello</span></div>"

  let assert Ok(tag) =
    soup.find_one([soup.tag("span")], soup.get_tag())
    |> soup.scrape(page)

  format_snap(page, "find_one span tag, get tag name", tag)
  |> birdie.snap("get_tag extracts the tag name")
}

pub fn get_attributes_test() {
  let page = "<a href=\"/home\" class=\"link primary\" data-id=\"123\">Home</a>"

  let assert Ok(attrs) =
    soup.find_one([soup.tag("a")], soup.get_attributes())
    |> soup.scrape(page)

  attrs
  |> list.map(fn(attr) { attr.0 <> "=" <> attr.1 })
  |> string.join(", ")
  |> format_snap(page, "find_one a tag, get all attributes", _)
  |> birdie.snap("get_attributes extracts all attributes")
}

pub fn get_text_test() {
  let page = "<p>Hello <strong>world</strong>!</p>"

  let assert Ok(text) =
    soup.find_one([soup.tag("p")], soup.get_text())
    |> soup.scrape(page)

  text
  |> string.join("")
  |> format_snap(page, "find_one p tag, get text content", _)
  |> birdie.snap("get_text extracts text content")
}

pub fn get_text_nested_test() {
  let page = "<div><p>First</p><p>Second</p></div>outside<div>another</div>"

  let assert Ok(text) =
    soup.find_one([soup.tag("div")], soup.get_text())
    |> soup.scrape(page)

  text
  |> string.join("|")
  |> format_snap(page, "find_one div tag, get all nested text content", _)
  |> birdie.snap("get_text extracts nested text content")
}

pub fn get_namespace_html_test() {
  let page = "<div>hello</div>"

  let assert Ok(ns) =
    soup.find_one([soup.tag("div")], soup.get_namespace())
    |> soup.scrape(page)

  case ns {
    soup.Html -> "Html"
    soup.Svg -> "Svg"
    soup.MathMl -> "MathMl"
  }
  |> format_snap(page, "find_one div tag, get namespace", _)
  |> birdie.snap("get_namespace returns Html for regular elements")
}

pub fn get_namespace_svg_test() {
  let page = "<svg><circle cx=\"50\" cy=\"50\" r=\"40\"></circle></svg>"

  let assert Ok(ns) =
    soup.find_one([soup.svg("circle")], soup.get_namespace())
    |> soup.scrape(page)

  case ns {
    soup.Html -> "Html"
    soup.Svg -> "Svg"
    soup.MathMl -> "MathMl"
  }
  |> format_snap(page, "find_one svg circle element, get namespace", _)
  |> birdie.snap("get_namespace returns Svg for svg elements")
}

pub fn map2_test() {
  let page = "<article><h1>Title</h1><p>Content here</p></article>"

  let assert Ok(result) =
    soup.find_one(
      [soup.tag("article")],
      soup.map2(
        soup.find_one([soup.tag("h1")], soup.get_text()),
        soup.find_one([soup.tag("p")], soup.get_text()),
        fn(title, content) {
          "Title: "
          <> string.join(title, "")
          <> " | Content: "
          <> string.join(content, "")
        },
      ),
    )
    |> soup.scrape(page)

  result
  |> format_snap(
    page,
    "find_one article, map2 to combine h1 text and p text",
    _,
  )
  |> birdie.snap("map2 combines two scrapers")
}

pub fn map3_test() {
  let page =
    "<div data-id=\"42\"><span class=\"name\">Alice</span><span class=\"role\">Admin</span></div>"

  let assert Ok(result) =
    soup.find_one(
      [soup.tag("div")],
      soup.map3(
        soup.get_attributes(),
        soup.find_one([soup.class("name")], soup.get_text()),
        soup.find_one([soup.class("role")], soup.get_text()),
        fn(attrs, name, role) {
          let id = case list.find(attrs, fn(a) { a.0 == "data-id" }) {
            Ok(#(_, v)) -> v
            _ -> "?"
          }
          "Id: "
          <> id
          <> ", Name: "
          <> string.join(name, "")
          <> ", Role: "
          <> string.join(role, "")
        },
      ),
    )
    |> soup.scrape(page)

  result
  |> format_snap(
    page,
    "find_one div, map3 to combine attributes, .name text, and .role text",
    _,
  )
  |> birdie.snap("map3 combines three scrapers")
}

pub fn map_transform_test() {
  let page = "<ul><li>one</li><li>two</li><li>three</li></ul>"

  let assert Ok(result) =
    soup.find_all([soup.tag("li")], soup.get_text())
    |> soup.map(fn(items) {
      items
      |> list.map(fn(texts) { string.uppercase(string.join(texts, "")) })
    })
    |> soup.scrape(page)

  result
  |> string.join(", ")
  |> format_snap(page, "find_all li, get text, map to uppercase", _)
  |> birdie.snap("map transforms scraper results")
}

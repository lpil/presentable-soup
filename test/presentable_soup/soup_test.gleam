import birdie
import presentable_soup/soup

pub fn element_to_string_preserve_whitespace_element_test() {
  [
    soup.Element("div", [], [
      soup.Element("script", [], [
        soup.Text(
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
    soup.Element("h1", [], [soup.Text("Hello, Joe!")]),
  ]
  |> soup.elements_to_string
  |> birdie.snap("text nodes without space around do not gain space")
}

pub fn element_to_string_whitespace_before_text_test() {
  [
    soup.Element("h1", [], [soup.Text(" space")]),
  ]
  |> soup.elements_to_string
  |> birdie.snap("text nodes can have whitespace before")
}

pub fn element_to_string_whitespace_after_text_test() {
  [
    soup.Element("h1", [], [soup.Text("space ")]),
  ]
  |> soup.elements_to_string
  |> birdie.snap("text nodes can have whitespace after")
}

pub fn element_to_string_whitespace_between_text_test() {
  [
    soup.Element("h1", [], [
      soup.Text("one "),
      soup.Element("span", [], [soup.Text("two")]),
      soup.Text("three "),
      soup.Element("span", [], [soup.Text(" four ")]),
      soup.Text(" five"),
    ]),
  ]
  |> soup.elements_to_string
  |> birdie.snap("text nodes can have whitespace between when safe")
}

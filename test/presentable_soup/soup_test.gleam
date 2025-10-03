import birdie
import gleam/list
import presentable_soup as soup

// pub fn element_to_string_preserve_whitespace_element_test() {
//   [
//     soup.ElementNode("div", [], [
//       soup.ElementNode("script", [], [
//         soup.TextNode(
//           "function main() {
//   console.log(1);
// }
//
// main();",
//         ),
//       ]),
//     ]),
//   ]
//   |> soup.elements_to_string
//   |> birdie.snap(
//     "script tags don't have their inner content padded or indented",
//   )
// }
//
// pub fn element_to_string_no_whitespace_text_test() {
//   [
//     soup.ElementNode("h1", [], [soup.TextNode("Hello, Joe!")]),
//   ]
//   |> soup.elements_to_string
//   |> birdie.snap("text nodes without space around do not gain space")
// }
//
// pub fn element_to_string_whitespace_before_text_test() {
//   [
//     soup.ElementNode("h1", [], [soup.TextNode(" space")]),
//   ]
//   |> soup.elements_to_string
//   |> birdie.snap("text nodes can have whitespace before")
// }
//
// pub fn element_to_string_whitespace_after_text_test() {
//   [
//     soup.ElementNode("h1", [], [soup.TextNode("space ")]),
//   ]
//   |> soup.elements_to_string
//   |> birdie.snap("text nodes can have whitespace after")
// }
//
// pub fn element_to_string_whitespace_between_text_test() {
//   [
//     soup.ElementNode("h1", [], [
//       soup.TextNode("one "),
//       soup.ElementNode("span", [], [soup.TextNode("two")]),
//       soup.TextNode("three "),
//       soup.ElementNode("span", [], [soup.TextNode(" four ")]),
//       soup.TextNode(" five"),
//     ]),
//   ]
//   |> soup.elements_to_string
//   |> birdie.snap("text nodes can have whitespace between when safe")
// }
//
// pub fn scrape_0_test() {
//   let page =
//     "
// <header>
//   <h1>Lustre Labs</h1>
//   Woop!
// </header>
//     "
//
//   let assert Ok(element) =
//     soup.find_one([soup.tag("h1")], soup.get_tree())
//     |> soup.scrape(page)
//
//   [element]
//   |> soup.elements_to_string
//   |> birdie.snap("scrape_0_test")
// }
//
// pub fn scrape_1_test() {
//   let page =
//     "
// <header>
//   <h1>
//     <br class=1>
//     <br class=2>
//   </h1>
// </header>
//     "
//
//   let assert Ok(element) =
//     soup.find_one([soup.tag("h1")], soup.get_tree())
//     |> soup.scrape(page)
//
//   [element]
//   |> soup.elements_to_string
//   |> birdie.snap("scrape_1_test")
// }

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
  |> birdie.snap("scrape_2_test")
}
// pub fn scrape_3_test() {
//   let page =
//     "
// <header>
//   <p>one</p>
//   <p>two</p>
//   <div>
//     <p>three</p>
//     <p>four</p>
//   </div>
// </header>
//     "
//
//   let assert Ok(element) =
//     soup.find_all([soup.tag("p")], soup.get_tree())
//     |> soup.scrape(page)
//
//   element
//   |> soup.elements_to_string
//   |> birdie.snap("scrape_3_test")
// }
//
// pub fn scrape_4_test() {
//   let page =
//     "
// <header>
//   <p>zero</p>
//   <p><span>one</span></p>
//   <p><span>two</span></p>
//   <div>
//     <p><span>three</span></p>
//     <p><span>four</span></p>
//     <p>five</p>
//   </div>
// </header>
//     "
//
//   let assert Ok(element) =
//     soup.find_all(
//       [soup.tag("p")],
//       soup.find_one([soup.tag("span")], soup.get_tree()),
//     )
//     |> soup.scrape(page)
//
//   element
//   |> soup.elements_to_string
//   |> birdie.snap("scrape_4_test")
// }
//
// pub fn scrape_5_test() {
//   let page =
//     "
// <p><span>five</span></p>
//     "
//
//   let assert Ok(element) =
//     soup.find_all(
//       [soup.tag("p")],
//       soup.find_all([soup.tag("span")], soup.get_tree()),
//     )
//     |> soup.map(list.flatten)
//     |> soup.scrape(page)
//
//   element
//   |> soup.elements_to_string
//   |> birdie.snap("scrape_5_test")
// }

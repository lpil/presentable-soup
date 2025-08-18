# presentable_soup

Querying, scraping, and parsing of HTML. Good for snapshot testing too!

[![Package Version](https://img.shields.io/hexpm/v/presentable_soup)](https://hex.pm/packages/presentable_soup)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/presentable_soup/)

```sh
gleam add presentable_soup@1
```
```gleam
import presentable_soup as soup

pub fn main() -> Nil {
  // You've got some HTML. Maybe this is downloaded from a website, or it's
  // generated in your tests. Anything is fine.
  let document = "
<!doctype html>
<head>
  <title>Presentable Soup Webpage</title>
</head>
<body>
  <h1 id=\"title\">Presentable Soup</h1>
  <p>Is it good? Yes I think it might be!</p>
  <aside>
    <p>Low memory use even for large documents.</p>
  </aside>
</body>
</html>
"

  // Construct a query, which is a description of what elements to match,
  // similar to a CSS selector.
  //
  // The `element` function matches a single element where all the items in the
  // list match. This is a query for a `h1` element with the id `"title"`.
  let query = soup.element([
    soup.tag("h1"),
    soup.id("title"),
  ])

  // The `find` function can be used to find a single element in the document
  // that matches the query.
  assert soup.find(in: document, matching: query)
    == Ok(soup.Element([#("id", "title")], [soup.Text("Presentable Soup")]))

  // The `find_all` function call be used to find all the elements the match
  // the query.
  assert soup.find_all(in: document, matching: soup.element([soup.tag("p")]))
    == Ok([
      soup.Element([], [soup.Text("Is it good? Yes I think it might be!")]),
      soup.Element([], [soup.Text("Low memory use even for large documents.")]),
    ])

  // The `descendant` function can be used to make a more complex query that
  // matches elements within some other element.
  // This query matches any `p` element that is within an `aside` element.
  let query =
    soup.element([soup.tag("aside")])
    |> soup.descendant([soup.tag("p")])
  assert soup.find_all(in: document, matching: query)
    == Ok([
      soup.Element([], [soup.Text("Low memory use even for large documents."),
    ]))
}

// The returned elements can be rendered as HTML. This is especially useful
// for snapshot testing!
// Don't test your generated HTML by looking for sub-strings, instead query
// for the parts of the page that matter for each test and then snapshot it
// with a library like Giacomo Cavalieri's Birdie.
pub fn contact_page_test() {
  let webpage = my_app.handle_request("/contact")

  // Query the page. In this test I want to focus on the contact form.
  let query = soup.element([soup.tag("form"), soup.class("contact-form")])
  let assert Ok(found) = soup.find_all(webpage, query) as "html must be valid"

  // Render the matched HTML, create a descriptive snapshot string, and
  // snapshot it!
  let snapshot =
    "Contact page `form` with class `contact-form`\n\n"
    <> soup.elements_to_string(found)
  birdie.snap("contact page form", snapshop)
}
```

Further documentation can be found at <https://hexdocs.pm/presentable_soup>.

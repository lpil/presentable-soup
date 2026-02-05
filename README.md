# Presentable Soup

Efficient querying, scraping, and parsing of HTML. Good for snapshot testing too!

[![Package Version](https://img.shields.io/hexpm/v/presentable_soup)](https://hex.pm/packages/presentable_soup)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/presentable_soup/)

This package supports the Gleam Erlang target.

```sh
gleam add presentable_soup@2
```
```gleam
import presentable_soup as soup
import gleam/list
import gleam/result

pub fn main() {
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

  // Use `element` to start a query for the first element matching all the
  // given matchers, and `scrape` to run it on some HTML.
  soup.element([soup.with_tag("h1"), soup.with_id("title")])
  |> soup.return(soup.text_content())
  |> soup.scrape(document)
  |> echo
  // -> Ok("Presentable Soup")

  // Different scrapers can be use with `return` to extract different data
  // from the queried element.
  soup.element([soup.with_tag("h1")])
  |> soup.return(soup.attributes())
  |> soup.scrape(document)
  |> echo
  // -> Ok([#("id", "title")])

  // Use `elements` to scrape multiple matching elements.
  soup.elements([soup.with_tag("p")])
  |> soup.return(soup.text_content())
  |> soup.scrape(document)
  |> echo
  // -> Ok([
  //   "Is it good? Yes I think it might be!",
  //   "Low memory use even for large documents.",
  // ])

  // The `descendant` function can be used to make a more complex query that
  // matches elements within some other element.
  // This query matches any `p` element that is within an `aside` element.
  soup.element([soup.with_tag("aside")])
  |> soup.descendant([soup.with_tag("p")])
  |> soup.return(soup.text_content())
  |> soup.scrape(document)
  |> echo
  // -> Ok(["Low memory use even for large documents."])

  // Often we need to extract multiple things from one element.
  // To do this we can combine multiple scrapers into one:
  let id_and_text = {
    use attrs, txt <- soup.merge2(soup.attributes(), soup.text_content())
    let id = list.key_find(attrs, "id") |> result.unwrap("<no id>")
    "#" <> id <> ": " <> text
  }
  soup.element([soup.with_tag("h1")])
  |> soup.return(id_and_text)
  |> soup.scrape(document)
  |> echo
  // -> Ok("title: Presentable Soup")


  // More complex scrapers can be combined to get data from multiple
  // elements within a query.
  let document = "
<div class='pokemon' data-type='grass'>
  <title>Bulbasaur</title>
  A chill leafy guy.
</div>
<div class='pokemon' data-type='fire'>
  <title>Charmander</title>
  Creates steam when it rains.
</div>
<div class='pokemon' data-type='water'>
  <title>Squirtle</title>
  Looks rad in sunglasses.
</div>
"
  let pokemon_name =
    soup.element([soup.with_tag("title")])
    |> soup.returning(soup.text_content())
  let pokemon_type =
    soup.attributes()
    |> soup.try_map(list.key_find(_, "type"))
  let pokemon = {
    use name, type_ <- soup.merge2(pokemon_name, pokemon_type)
    Pokemon(name:, type_:)
  }
  soup.element([soup.with_class("pokemon")])
  |> soup.return(pokemon)
  |> soup.scrape(document)
  |> echo
  // -> Ok([
  //   Pokemon(name: "Bulbasaur", type_: "grass"),
  //   Pokemon(name: "Charmander", type_: "fire"),
  //   Pokemon(name: "Squirtle", type_: "water"),
  // ])
}

pub type Pokemon {
  Pokemon(name: String, type_: String)
}

// The returned elements can be rendered as HTML. This is especially useful
// for snapshot testing!
// Don't test your generated HTML by looking for sub-strings, instead query
// for the parts of the page that matter for each test and then snapshot it
// with a library like Giacomo Cavalieri's Birdie.
pub fn contact_page_test() {
  let webpage = my_app.handle_request("/contact")

  // Query the page. In this test I want to focus on the contact form.
  let assert Ok(found) =
    soup.elements([soup.with_tag("form"), soup.with_class("contact-form")])
    |> soup.return(soup.element_tree())
    |> soup.scrape(webpage)

  // Render the matched HTML, create a descriptive snapshot string, and
  // snapshot it!
  let snapshot =
    "Contact page `form` with class `contact-form`\n\n"
    <> soup.elements_to_string(found)
  birdie.snap("contact page form", snapshot)
}
```

Further documentation can be found at <https://hexdocs.pm/presentable_soup>.

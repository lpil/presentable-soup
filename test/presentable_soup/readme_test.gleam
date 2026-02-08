import gleam/list
import gleam/result
import gleam/string
import presentable_soup as soup

pub fn main() {
  // You've got some HTML. Maybe this is downloaded from a website, or it's
  // generated in your tests. Anything is fine.
  let document =
    "
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
  let scraped =
    soup.element([soup.with_tag("h1"), soup.with_id("title")])
    |> soup.return(soup.text_content())
    |> soup.scrape(document)
  assert scraped == Ok(["Presentable Soup"])

  // Different scrapers can be use with `return` to extract different data
  // from the queried element.
  let scraped =
    soup.element([soup.with_tag("h1")])
    |> soup.return(soup.attributes())
    |> soup.scrape(document)
  assert scraped == Ok([#("id", "title")])

  // Use `elements` to scrape multiple matching elements.
  let scraped =
    soup.elements([soup.with_tag("p")])
    |> soup.return(soup.text_content())
    |> soup.scrape(document)
  assert scraped
    == Ok([
      ["Is it good? Yes I think it might be!"],
      ["Low memory use even for large documents."],
    ])

  // The `descendant` function can be used to make a more complex query that
  // matches elements within some other element.
  // This query matches any `p` element that is within an `aside` element.
  let scraped =
    soup.element([soup.with_tag("aside")])
    |> soup.descendant([soup.with_tag("p")])
    |> soup.return(soup.text_content())
    |> soup.scrape(document)
  assert scraped == Ok(["Low memory use even for large documents."])

  // Often we need to extract multiple things from one element.
  // To do this we can combine multiple scrapers into one:
  let id_and_text = {
    use attrs, text <- soup.merge2(soup.attributes(), soup.text_content())
    let id = list.key_find(attrs, "id") |> result.unwrap("<no id>")
    "#" <> id <> ": " <> string.join(text, "\n")
  }
  let scraped =
    soup.element([soup.with_tag("h1")])
    |> soup.return(id_and_text)
    |> soup.scrape(document)
  assert scraped == Ok("title: Presentable Soup")

  // More complex scrapers can be combined to get data from multiple
  // elements within a query.
  let document =
    "
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
    |> soup.return(soup.text_content())
    |> soup.map(string.concat)
  let pokemon_type =
    soup.attributes()
    |> soup.try_map(list.key_find(_, "type"))
  let pokemon = {
    use name, type_ <- soup.merge2(pokemon_name, pokemon_type)
    Pokemon(name:, type_:)
  }
  let scraped =
    soup.elements([soup.with_class("pokemon")])
    |> soup.return(pokemon)
    |> soup.scrape(document)
  assert scraped
    == Ok([
      Pokemon(name: "Bulbasaur", type_: "grass"),
      Pokemon(name: "Charmander", type_: "fire"),
      Pokemon(name: "Squirtle", type_: "water"),
    ])
}

pub type Pokemon {
  Pokemon(name: String, type_: String)
}

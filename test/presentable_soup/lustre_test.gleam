// IMPORTS ---------------------------------------------------------------------

import birdie
import presentable_soup as soup

// SINGLE ELEMENTS -------------------------------------------------------------

pub fn find_element_by_id_test() {
  let assert Ok(element) =
    soup.get_one([soup.id("login-form")], soup.get_tree())
    |> soup.scrape(page)
  [element]
  |> soup.elements_to_string
  |> birdie.snap("[find] Login form by id")
}

pub fn find_element_by_tag_test() {
  let assert Ok(element) =
    soup.get_one([soup.tag("h1")], soup.get_tree())
    |> soup.scrape(page)

  [element]
  |> soup.elements_to_string
  |> birdie.snap("[find] Wordmark by tag")
}

pub fn find_element_by_class_test() {
  let assert Ok(element) =
    soup.get_one([soup.class("cta")], soup.get_tree())
    |> soup.scrape(page)

  [element]
  |> soup.elements_to_string
  |> birdie.snap("[find] Call to action button by class")
}

pub fn find_element_by_multiple_classes_test() {
  let assert Ok(element) =
    soup.get_one([soup.class("content hero")], soup.get_tree())
    |> soup.scrape(page)

  [element]
  |> soup.elements_to_string
  |> birdie.snap("[find] Hero section by multiple classes")
}

// pub fn find_element_by_inline_style_test() {
//   let assert Ok(element) =
//     soup.find_one([soup.style("list-style-type", "none")], soup.get_tree())
//     |> soup.scrape(page)
//
//   [element]
//   |> soup.elements_to_string()
//   |> birdie.snap("[find] Features list by inline style")
// }
//
// pub fn find_element_by_text_content_test() {
//   let query = soup.element(matching: text("©"))
//   let assert Ok(element) = soup.find(in: page, matching: query)
//
//   [element]
//   |> soup.html_to_string
//   |> birdie.snap("[find] Copyright notice by text")
// }
//
pub fn find_child_by_tag_test() {
  let assert Ok(element) =
    soup.get_one(
      [soup.tag("form")],
      soup.get_one([soup.tag("h2")], soup.get_tree()),
    )
    |> soup.scrape(page)

  [element]
  |> soup.elements_to_string
  |> birdie.snap("[find] Login form title by child selector")
}

pub fn find_child_descendant_by_data_attribute_test() {
  let assert Ok(element) =
    soup.get_one(
      [soup.tag("header")],
      soup.get_one(
        [soup.tag("nav")],
        soup.get_one(
          [soup.tag("a"), soup.data("active", "true")],
          soup.get_tree(),
        ),
      ),
    )
    |> soup.scrape(page)

  [element]
  |> soup.elements_to_string
  |> birdie.snap("[find] Active link by child and descendant selector")
}

pub fn find_descendant_by_attribute_test() {
  let assert Ok(element) =
    soup.get_one(
      [soup.tag("form")],
      soup.get_one(
        [soup.tag("button"), soup.attribute("type", "submit")],
        soup.get_tree(),
      ),
    )
    |> soup.scrape(page)

  [element]
  |> soup.elements_to_string
  |> birdie.snap("[find] Submit button by descendant selector")
}

// // MULTIPLE ELEMENTS -----------------------------------------------------------
//
// pub fn find_all_by_tag_test() {
//   let query = soup.element([soup.tag("section")])
//   let assert Ok(elements) = soup.find_all(in: page, matching: query)
//
//   elements
//   |> soup.elements_to_string
//   |> birdie.snap("[find_all] All sections by tag")
// }
//
// pub fn find_all_by_attribute_test() {
//   let query = soup.element([soup.attribute("href", "")])
//   let assert Ok(elements) = soup.find_all(in: page, matching: query)
//
//   elements
//   |> soup.elements_to_string
//   |> birdie.snap("[find_all] All links with href attribute")
// }
//
// pub fn find_all_by_class_test() {
//   let query = soup.element([soup.class("vertical-nav")])
//   let assert Ok(elements) = soup.find_all(in: page, matching: query)
//
//   elements
//   |> soup.elements_to_string
//   |> birdie.snap("[find_all] All footer nav sections by class")
// }

const page: String = "
<header>
  <h1>Lustre Labs</h1>
  <nav>
    <ul class=\"horizontal-nav\">
      <li>
        <a data-active=\"true\" href=\"/\">
          Home
        </a>
      </li>
      <li>
        <a href=\"/contact\">
          Contact
        </a>
      </li>
    </ul>
  </nav>
</header>
<div>
  <main class=\"hero\">
    <form id=\"login-form\">
      <h2>
        Login
      </h2>
      <label>
        <p>
          Email
        </p>
        <input name=\"email\" type=\"email\">
      </label>
      <label>
        <p>
          Password
        </p>
        <input name=\"password\" type=\"password\">
      </label>
      <div class=\"form-actions\">
        <button class=\"primary\" type=\"submit\">
          Sign In
        </button>
        <a href=\"/forgot-password\">
          Forgot Password?
        </a>
      </div>
      <p class=\"form-footer\">
        Don&#39;t have an account?
        <a href=\"/signup\">
          Sign up
        </a>
      </p>
    </form>
  </main>
  <section class=\"hero content\">
    <h2>
      The Universal Framework
    </h2>
    <p>
      Static HTML, SPAs, Web Components, and interactive Server Components.
    </p>
    <button class=\"cta\">
      Get Started
    </button>
  </section>
  <section class=\"content\">
    <h2>
      Features
    </h2>
    <ul style=\"list-style-type:none;\">
      <li>
        Feature 1
      </li>
      <li>
        Feature 2
      </li>
      <li>
        Feature 3
      </li>
    </ul>
  </section>
  <section class=\"content\">
    <h2>
      Testimonials
    </h2>
    <div>
      <blockquote>
        <p>
          Lustre is amazing!
        </p>
        <cite>
          John Doe
        </cite>
      </blockquote>
      <blockquote>
        <p>
          I love using Lustre!
        </p>
        <cite>
          Jane Smith
        </cite>
      </blockquote>
    </div>
  </section>
</div>
<footer>
  <p>
    Built with 💕 by Lustre Labs
  </p>
  <nav>
    <ul class=\"vertical-nav\">
      <h2>
        Lustre Pro
      </h2>
      <li>
        <a href=\"/dashboard\">
          Dashboard
        </a>
      </li>
      <li>
        <a href=\"/faq\">
          FAQ
        </a>
      </li>
      <li>
        <a href=\"/pricing\">
          Pricing
        </a>
      </li>
    </ul>
    <ul class=\"vertical-nav\">
      <h2>
        Lustre
      </h2>
      <li>
        <a href=\"https://hexdocs.pm/lustre\">
          Documentation
        </a>
      </li>
      <li>
        <a href=\"https://github.com/lustre-labs/lustre\">
          GitHub
        </a>
      </li>
    </ul>
    <ul class=\"vertical-nav\">
      <h2>
        Legal
      </h2>
      <li>
        <a href=\"/terms-of-service\">
          Terms of service
        </a>
      </li>
      <li>
        <a href=\"/privacy-policy\">
          Privacy policy
        </a>
      </li>
      <li>
        <a href=\"/impressum\">
          Impressum
        </a>
      </li>
    </ul>
  </nav>
  <p>
    © 2025 Lustre Labs BV.
    <br>
    All rights reserved.
  </p>
</footer>
"

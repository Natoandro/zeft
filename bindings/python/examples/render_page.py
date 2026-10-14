"""Render an HTML page with a reusable Zeft template."""

import zeft


PAGE = """\
<main>
  <h1>{{ title }}</h1>
  <ul>{#for item in items}<li>{{ item.name }}: {{ item.description }}</li>{/for}</ul>
</main>
"""


def main() -> None:
    context = {
        "title": "Today's specials",
        "items": [
            {"name": "Tea", "description": "Bright & aromatic"},
            {"name": "Cake", "description": "Baked by Ada <3"},
        ],
    }

    with zeft.compile(PAGE) as template:
        print(template.render(context))


if __name__ == "__main__":
    main()

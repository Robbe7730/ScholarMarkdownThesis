# ScholarMarkdownThesis

Template to use [ScholarMarkdown][scholarmarkdown] for a Ghent University
masters thesis.

## Development mode

```
bundle install
bundle exec guard
```

## Build

```
bundle install
bundle exec nanoc compile
```

View on http://localhost:3000/


[scholarmarkdown]: https://github.com/rubensworks/ScholarMarkdown/

## Generate PDF

The HTML-version of the thesis also has a PDF export available. It is possible
to generate one by printing this page and selecting "Save to PDF".  The
submitted version was generated in **Firefox** with a scale of 100 and margins of
0.78 inch.
Set `print.save_as_pdf.internal_destinations.enabled` to `true` in
Firefox's `about:config` to make internal links to e.g. other sections work in
the PDF version. This might entirely break PDF generation though.
Printing from Google Chrome gives an incorrect result, only Firefox is supported
at the moment.

## Examples

- https://thesis.robbevanherck.be
- https://thesis.jan-pieter.be
- https://thesis.smessie.com

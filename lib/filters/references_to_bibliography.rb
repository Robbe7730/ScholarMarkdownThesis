# Replacement for https://github.com/rubensworks/ScholarMarkdown/blob/master/lib/scholarmarkdown/filter/references_to_footer.rb

require 'nokogiri'

Nanoc::Filter.define(:scholar_references_to_bibliography) do |content|
  doc = Nokogiri::HTML(content.dup)
  references = doc.css("dl.references:not(.custom-references)")
  if references
    doc.css("h2#references").unlink
    references.unlink
    doc.css("#bibliography").first.add_child(references)
  end
  doc.to_html
end

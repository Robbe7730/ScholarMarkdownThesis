require 'bibmarkdown'
require 'bibtex'
require 'csl/styles'
require 'nokogiri'

# Sets the default directory of citation styles.
CSL::Style.root = File.dirname(__FILE__) + '/../citationstyles'

Nanoc::Filter.define(:custom_citation) do |content, params|
  bib = params[:bibfile]
  if not bib
    raise "could not find bibliography file"
  end

  tag = params[:tag] || "custom"

  section = params[:section].raw_content

  # Generate the new section
  entries = BibTeX.parse(bib.raw_content).entries
  entries.each_value { |e| e.convert!(:latex) { |key| key != :url } }
  params = params.merge(entries: entries)
  new_section = BibMarkdown::Document.new(section, params).to_markdown

  # Add .custom-references to bibliography
  new_section.gsub! %{<dl class="references">}, %{<dl class="references custom-references">}

  # Replace ref-{number} with ref-{tag}-{number} to avoid id collisions
  new_section.gsub! %r{(?<=ref-)(?=[0-9]*)} , (tag + "-")

  # Something happens so that [] becomes \[\]
  new_section.gsub! %r{\\\[(.*)\\\]}, "[\\1]"

  content = content.dup
  content[section] = new_section
  content
end

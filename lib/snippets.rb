require 'erb'

# Proper escaping of IRIs
include ERB::Util

# Create a section block with the given file contents
def section id, classes = nil, overrideId = nil
  section_suffix=''
  if classes
    section_suffix=" class=\"" + classes + "\""
  end

  if not overrideId
    overrideId = "sec:" + id
  end

  section_suffix = section_suffix + " id=\"" + overrideId + "\""

  item = @items["/#{id.to_s}.*"]
  if not item
    raise "Could not find the file '" + id.to_s + "'"
  end
  <<-HTML
<section #{section_suffix} datatype="rdf:HTML" markdown="block">
#{item.raw_content}
</section>
  HTML
end

# Create a person block
def person name, website, profile, mainAuthor = true
  if mainAuthor
    # Add person to global list of authors
    unless $authors
      $authors = []
    end
    $authors.push(name)
  end

  if not website
    h name
  elsif not profile
    %{<a href="#{h website}">#{h name}</a>}
  else
    if mainAuthor
      %{<a rev="lsc:participatesIn" property="foaf:maker schema:creator schema:author schema:publisher" href="#{h website}" typeof="foaf:Person schema:Person" resource="#{profile}">#{h name}</a>}
    else
      %{<a rev="lsc:participatesIn" property="schema:contributor" href="#{h website}" typeof="foaf:Person schema:Person" resource="#{profile}">#{h name}</a>}
    end
  end
end

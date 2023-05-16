require 'csv'

Nanoc::Filter.define(:scholar_labelify) do |content, params|
  @max_depth = params[:max_depth] || 3

  if params[:acronyms]
    @acronyms = CSV.parse(params[:acronyms].raw_content, :headers => true)
  else
    @acronyms = []
  end

  if params[:ontologies]
    @ontologies = CSV.parse(params[:ontologies].raw_content, :headers => true)
  else
    @ontologies = []
  end

  content = Nokogiri::HTML(content.dup)

  # Keep track of figures and listings
  @figures = []
  @listings = []

  # Maps ID to how they should be referenced (in text)
  @display_name = {}

  # Keep the section numbering ([chapter, section, subsection, subsubsection])
  @section_numbering = [0, 0, 0, 0]

  # Keep track if we are in a numbered section
  @numbered = [false, false, false, false]

  # Keep track if we are in an appendix section
  @appendix = [false, false, false, false]

  # Keep the ToC entries
  @toc_entries = []

  # First pass, find figures and titles, label figures and set up ToC
  content = content.traverse { |node| process_node_1 node }

  # Second pass, add names to links and create TOCs
  content = content.traverse { |node| process_node_2 node }

  ret = content.to_s

  # Named Entity Recognition 🤔
  @acronyms.each do |acronym|
    ret.gsub! %r{(?<=[\s\.,!?])#{acronym['abbreviation']}(?=[\s\.,!?])} do |match|
      %{<abbr title='#{acronym['full']}'>#{acronym['abbreviation']}</abbr>}
    end
  end

  ret
end

def process_node_1 node
  case node.name
  when "figure"
    process_figure node
  when "h1", "h2", "h3", "h4"
    process_title node
  when "section"
    process_section node
  else
    node
  end
end

def process_node_2 node
  if node.name == "a"
    process_link node
  elsif node[:id] == "list-of-listings"
    create_list node, @listings, "Listing"
  elsif node[:id] == "list-of-figures"
    create_list node, @figures, "Figure"
  elsif node[:id] == "table-of-contents"
    create_toc node
  elsif node[:id] == "list-of-acronyms"
    create_dict node, acronym_dict, "Acronym"
  elsif node[:id] == "list-of-ontologies"
    create_dict node, ontology_dict, "Ontology", "List of Ontologies"
  else
    node
  end
end

# Add label to figures and listings and keep their captions in the corresponding lists
def process_figure node
  if (node[:class] && (node[:class].include? "listing") && !(node[:id].start_with? "lst:"))
    raise "Invalid id for listing " + node[:id]
  end

  # No listing == figure
  if ((!node[:class] || !(node[:class].include? "listing")) && !(node[:id].start_with? "fig:"))
    raise "Invalid id for figure " + node[:id]
  end

  figcaption = node.css("figcaption").first

  if figcaption
    caption = figcaption.text.strip
    figcaption.remove()
  else
    caption = "No caption."
  end

  caption.gsub! "\n", " "

  if node.classes().include? "listing"
    @listings.append({
      :text => caption,
      :ref => node[:id]
    })
    label_value = "Listing " + @listings.size.to_s
  else
    @figures.append({
      :text => caption,
      :ref => node[:id]
    })
    label_value = "Figure " + @figures.size.to_s
  end

  if @display_name.has_key?(node[:id])
    raise "Duplicate id: " + node[:id]
  end
  @display_name[node[:id]] = label_value

  node.add_child(
    "<figcaption>" +
      "<p>" +
        "<span class=\"label\">" + label_value + ":</span>" +
        figcaption +
      "</p>" +
    "</figcaption>"
  )
end

# Check titles, adding them to the toc and making sure their id is correctly tagged
def process_title node
  current_chapter = node
  while current_chapter.parent && !(current_chapter[:class] && (current_chapter[:class].include? "chapter"))
    current_chapter = current_chapter.parent
  end

  new_id = node.text
  new_id.downcase!
  new_id.gsub! %r{(?<=[a-zA-Z0-9()])[ \-_/](?=[a-zA-Z0-9()])}, "-"
  new_id.gsub! %r{[^a-z\-]}, ""
  if not node["id"]
    # Only automatically add generated ID in case no ID was manually specified
    node[:id] = node.name + ":" + current_chapter[:id] + "/" + new_id
  end

  index = ["h1", "h2", "h3", "h4"].index node.name

  # Indicate if we are in a numbered or appendix section
  # A section is numbered if it does not have the "noincrement" class and none
  # of the parent headers are not numbered
  numbered = !(node.classes.include? "noincrement") && (0..(index-1)).none? { |x| !@numbered[x] }
  appendix = (node.parent.classes.include? "appendix") || (node.classes.include? "appendices") && (0..(index-1)).none? { |x| !@appendix[x] }

  for i in index..3
    @numbered[i] = numbered
    @appendix[i] = appendix
  end

  # Add an incrementing counter at the end of the node ID in case it is not unique
  while @display_name.has_key?(node[:id])
    if node[:id].match(/_[0-9]+$/)
      # Increment the counter
      node[:id] = node[:id].gsub(/\d+$/,&:next)
    else
      # Add the counter
      node[:id] += "_1"
    end
  end
  # Should now be unique
  if @display_name.has_key?(node[:id])
    raise "Duplicate id: " + node[:id]
  end

  if not @numbered[index]
    @display_name[node[:id]] = node.text
  else
    # First, update numbering
    for i in (index+1)..3
      @section_numbering[i] = 0
    end
    @section_numbering[index] += 1

    # Next, find the display name and add it to the ToC
    case node.name
    when "h1"
      if @appendix[index]
        @display_name[node[:id]] = @section_numbering
        @toc_entries.append({
          :number => "",
          :name => node.text,
          :id => node[:id],
          :children => []
        })
      else
        @display_name[node[:id]] = "Chapter %d" % @section_numbering
        @toc_entries.append({
          :number => "%d" % @section_numbering,
          :name => node.text,
          :id => node[:id],
          :children => []
        })
      end
    when "h2"
      if @appendix[index]
        @display_name[node[:id]] ="Appendix %s" % (@section_numbering[1] + 64).chr
        @toc_entries.last[:children].append({
          :number => "%s" % (@section_numbering[1] + 64).chr,
          :name => node.text,
          :id => node[:id],
          :children => []
        })
      else
        @display_name[node[:id]] = "Section %d.%d" % @section_numbering
        @toc_entries.last[:children].append({
          :number => "%d.%d" % @section_numbering,
          :name => node.text,
          :id => node[:id],
          :children => []
        })
      end
    when "h3"
      if @appendix[index]
        @display_name[node[:id]] = "Section %s.%d" % [(@section_numbering[1] + 64).chr, @section_numbering[2]]
        @toc_entries.last[:children].last[:children].append({
          :number => "%s.%d" % [(@section_numbering[1] + 64).chr, @section_numbering[2]],
          :name => node.text,
          :id => node[:id],
          :children => []
        })
      else
        @display_name[node[:id]] = "Subsection %d.%d.%d" % @section_numbering
        @toc_entries.last[:children].last[:children].append({
          :number => "%d.%d.%d" % @section_numbering,
          :name => node.text,
          :id => node[:id],
          :children => []
        })
      end
    when "h4"
      if @appendix[index]
        @display_name[node[:id]] = "Subsection %s.%d.%d" % [(@section_numbering[1] + 64).chr, @section_numbering[2], @section_numbering[3]]
        @toc_entries.last[:children].last[:children].last[:children].append({
          :number => "%s.%d.%d" % [(@section_numbering[1] + 64).chr, @section_numbering[2], @section_numbering[3]],
          :name => node.text,
          :id => node[:id],
          :children => []
        })
      else
        @display_name[node[:id]] = "Subsubsection %d.%d.%d.%d" % @section_numbering
        @toc_entries.last[:children].last[:children].last[:children].append({
          :number => "%d.%d.%d.%d" % @section_numbering,
          :name => node.text,
          :id => node[:id],
          :children => []
        })
      end
    end

  end
  node
end

def process_section node
  if @display_name.has_key?(node[:id])
    raise "Duplicate id: " + node[:id]
  end

  if node[:class] && (node[:class].include? "chapter")
    @display_name[node[:id]] = "Chapter %d" % @section_numbering
  else
    @display_name[node[:id]] = "Section %d.%d" % @section_numbering
  end
end

# Find what the link references and change the text if needed
def process_link node
  if node[:href]
    # Not referencing this document
    if not node[:href][0] == "#"
      return node
    end

    # Overriden value
    if not node.text == ""
      return node
    end

    ref_id = node[:href][1..-1]

    if @display_name.include? ref_id
      node.inner_html = @display_name[ref_id]
    else
      # Otherwise, mark as invalid
      node.inner_html = "INVALID REFERENCE"
      node.add_class("todo")
      puts "Invalid reference: " + ref_id
    end
    node
  end
end

def create_list node, values, name, title = nil
  unless title
    title = "List of " + name + "s"
  end
  node.add_child("<h1 class=\"noincrement\">" + title + "</h1>")

  ul = node.add_child('<ul class="list-of"></ul>').first
  values.each do |value|
    if value[:ref]
      reference_text = "<a href=\"#" + value[:ref] + "\">" +
        "<span class=\"label\">" +
          @display_name[value[:ref]] +
        "</span>: " +
      "</a>"
    else
      reference_text = ""
    end
    ul.add_child("<li>" +
      reference_text +
      value[:text] +
    "</li>")
  end

  @display_name[node[:id]] = title

  ul
end

def create_dict node, entries, name, title = nil
  unless title
    title = "List of " + name + "s"
  end
  node.add_child("<h1 class=\"noincrement\">" + title + "</h1>")

  dl = node.add_child('<dl class="dict-of"></dl>').first

  entries.each do |entry|
    dl.add_child("<dt>" + entry[:key] + "</dt>")
    dl.add_child("<dd>" + entry[:value] + "</dd>")
  end

  @display_name[node[:id]] = title

  dl
end

def create_toc node
  node.add_child("<h1 class=\"noincrement\">Table of Contents</h1>")
  node.add_child(recursive_toc node, @toc_entries, 1)
  node
end

def recursive_toc node, entries, depth
  ul = node.add_child("<ul></ul>").first
  entries.each do |entry|
    li = ul.add_child(
      "<li>" +
        "<a href=\"#" + entry[:id] + "\">" +
          entry[:number] + " " + entry[:name] +
        "</a>" +
      "</li>"
    ).first
    unless entry[:children].empty? || depth >= @max_depth
      li.add_child(recursive_toc li, entry[:children], depth+1)
    end
  end
  ul
end

# Create a `create_dict` compatible list of acronyms
def acronym_dict
  @acronyms.map { |acronym| {
    :key => acronym['abbreviation'],
    :value => acronym['full'],
  } }
end

# Create a `create_dict` compatible list of ontologies
# TODO: this could probably use some RDFa
def ontology_dict
  @ontologies.map { |ontology| {
    :key => ontology['abbreviation'],
    :value => "<a href=\"" + ontology["uri"] + "\">" + ontology['name'] + "</a>"
  } }
end

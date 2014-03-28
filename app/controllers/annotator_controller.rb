
require 'json'
require 'cgi'

class AnnotatorController < ApplicationController
  layout 'ontology'

  # REST_URI is defined in application_controller.rb
  ANNOTATOR_URI = REST_URI + "/annotator"

  def index
    @semantic_types_for_select = []
    @semantic_types ||= get_semantic_types
    @semantic_types.each_pair do |code, label|
      @semantic_types_for_select << ["#{label} (#{code})", code]
    end
    @semantic_types_for_select.sort! {|a,b| a[0] <=> b[0]}
    @annotator_ontologies = LinkedData::Client::Models::Ontology.all
  end


  def create
    params[:mappings] ||= []
    params[:max_level] ||= 0
    params[:ontologies] ||= []
    params[:semantic_types] ||= []
    text_to_annotate = params[:text].strip.gsub("\r\n", " ").gsub("\n", " ")
    options = { :ontologies => params[:ontologies],
                :max_level => params[:max_level].to_i,
                :semantic_types => params[:semantic_types],
                :mappings => params[:mappings],
                # :wholeWordOnly => params[:wholeWordOnly] ||= true,  # service default is true
                # :withDefaultStopWords => params[:withDefaultStopWords] ||= true,  # service default is true
    }
    start = Time.now
    query = ANNOTATOR_URI
    query += "?text=" + CGI.escape(text_to_annotate)
    query += "&include=prefLabel"
    query += "&max_level=" + options[:max_level].to_s
    query += "&ontologies=" + CGI.escape(options[:ontologies].join(',')) unless options[:ontologies].empty?
    query += "&semantic_types=" + options[:semantic_types].join(',') unless options[:semantic_types].empty?
    query += "&mappings=" + options[:mappings].join(',') unless options[:mappings].empty?
    #query += "&wholeWordOnly=" + options[:wholeWordOnly].to_s unless options[:wholeWordOnly].empty?
    #query += "&withDefaultStopWords=" + options[:withDefaultStopWords].to_s unless options[:withDefaultStopWords].empty?
    annotations = parse_json(query) # See application_controller.rb
    #annotations = LinkedData::Client::HTTP.get(query)
    LOG.add :debug, "Retrieved #{annotations.length} annotations: #{Time.now - start}s"
    if annotations.empty? || params[:raw] == "true"
      # TODO: if params contains select ontologies and/or semantic types, only return those selected.
      response = {
          annotations: annotations,
          ontologies: get_simplified_ontologies_hash,  # application_controller
          semantic_types: get_semantic_types           # application_controller
      }
    else
      massage_annotated_classes(annotations, options)
      response = {
          annotations: annotations,
          ontologies: {},        # ontology data are in annotations already.
          semantic_types: {}     # semantic types are in annotations already.
      }
    end

    # Avoid highlighted match context in controller; it's more
    # overhead on controller and more data transfer to the client.
    # This is handled in bp_annotator.js, to move the processing load onto
    # the client side in JS.  (TODO: evaluate if JS handles UTF8.)
    #annotations.each do |a|
    #  #annotation = a['annotations'].first
    #  #=> {"from"=>1, "to"=>8, "matchType"=>"PREF", "text"=>"MELANOMA"}
    #  a['annotations'].each do |annotation|
    #    position = [annotation['from'], annotation['to']]
    #    context = highlight_and_get_context(text_to_annotate, position)
    #    annotation['context'] = context
    #  end
    #end
    render :json => response
  end


private

  ## This method can be used to highlight matched classes in the annotation text.  Currently done in JS on the client.
  #def highlight_and_get_context(text, position, words_to_keep = 4)
  #  # Process the highlighted text
  #  #highlight = ["<span style='color: #006600; padding: 2px 0; font-weight: bold;'>", "", "</span>"]
  #  highlight = ["<span class='annotator_context_highlight'>", "", "</span>"]
  #  highlight[1] = text.utf8_slice(position[0] - 1, position[1] - position[0] + 1)
  #  # Use scan to split the text on spaces while keeping the spaces
  #  #scan_filter = Regexp.new(/[ ]+?[-\?'"\+\.,]+\w+|[ ]+?[-\?'"\+\.,]+\w+[-\?'"\+\.,]|\w+[-\?'"\+\.,]+|[ ]+?\w+/)
  #  before = text.utf8_slice(0, position[0] - 1).match(/(\s+\S+|\S+\s+){0,4}$/).to_s
  #  after = text.utf8_slice(position[1], ActiveSupport::Multibyte::Chars.new(text).length - position[1]).match(/^(\S+\s+\S+|\s+\S+|\S+\s+){0,4}/).to_s
  #  # The process above will not keep a space right before the highlighted word, so let's keep it here if needed
  #  # 32 is the character code for space
  #  kept_space = text.utf8_slice(position[0] - 2) == " " ? " " : ""
  #  # Put it all together
  #  [before, kept_space, highlight.join, after].join
  #end

end


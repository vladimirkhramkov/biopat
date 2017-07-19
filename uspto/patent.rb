require 'nokogiri'
require 'open-uri'
require 'date'

class Patent
  attr_accessor :number,:country,:kind_code,:title
  attr_accessor :publication_type
  attr_accessor :application_number
  attr_accessor :publication_date
  attr_accessor :filing_date
  attr_accessor :priority_date
  attr_accessor :inventors, :assignees
  attr_accessor :published_as
  attr_accessor :abstract, :description
  attr_accessor :claims
  attr_accessor :patent_citations
  attr_accessor :non_patent_citations
  attr_accessor :referenced_by
  attr_accessor :international_classification
  attr_accessor :cooperative_classification
  attr_accessor :legal_events
  attr_accessor :sequences

  def initialize(args)
    self.inventors = []
    self.assignees = []
    self.published_as = []
    self.patent_citations = []
    self.non_patent_citations = []
    self.international_classification = []
    self.cooperative_classification = []
    self.claims = []
    self.referenced_by = []
    self.legal_events = []

    if args[:number]
      @number = args[:number]
      if args[:country]
        @country = args[:country]
      end
    elsif args[:filename]
      parse_html(args[:filename])
    end
  end

  def to_date(date)
    date.to_s.gsub(/\-/,'')
  end

  def parse_html(url)
    doc = Nokogiri::HTML(open(url))

    if (title = doc.css("invention-title"))
      @title = title.text
      puts @title
    end

    if (patent_number = doc.css("span.patent-number"))
      if patent_number.text =~ /^([A-Z]{2})\s*([A-Z]*[0-9]+)\s*([A-Z][0-9]*)?/
        @country   = $1
        @number    = $2
        @kind_code = $3
        puts "#{@country}, #{@number}, #{@kind_code}"
      end
    end

    if (abstract = doc.css("abstract"))
      @abstract = abstract.text.strip
      puts @abstract
    end

    if (description = doc.css("ul.description"))
      @description = description.text.strip
      #puts @description
    end

    if (claims = doc.css("div.claims div.claim div.claim"))
      claims.each do |claim|
        @claims << { num: claim["num"], text: claim.text.strip }
      end
    end

    if (claims = doc.css("div.claims div.claim-dependent div.claim"))
      claims.each do |claim|
        @claims << { num: claim["num"], text: claim.text.strip }
      end
    end

    return
  end
end

p = Patent.new(filename: 'https://www.google.com/patents/US20030162167')

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
  attr_accessor :published_as, :alternate_numbers
  attr_accessor :abstract, :description
  attr_accessor :claims
  attr_accessor :patent_citations
  attr_accessor :non_patent_citations
  attr_accessor :referenced_by
  attr_accessor :classifications
  attr_accessor :legal_events
  attr_accessor :sequences

  def initialize(args)
    self.inventors = []
    self.assignees = []
    self.published_as = []
    self.alternate_numbers = []
    self.patent_citations = []
    self.non_patent_citations = []
    self.classifications = []
    self.claims = []
    self.referenced_by = []
    self.legal_events = []
    self.sequences = []

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

  def publication_number_from_string(string)
    return if @number
    if string =~ /^([A-Z]{2})\s*([A-Z]*[0-9]+)\s*([A-Z][0-9]*)?/
      @country   = $1
      @number    = $2
      @kind_code = $3
      puts "#{@country}, #{@number}, #{@kind_code}"
    end
  end

  def parse_sequences
    text = @claims.map{|h| h[:text]}.join(' ') + " " + @description
    text.gsub!(/[-\t\r\n\s ]+/,' ')

    parse_nucleotides(text)
    parse_proteins(text)
    parse_amino_acids(text)
    order_sequences
  end

  def parse_nucleotides(text)
    dna_regex = /5′([ACGTU ]{4,})3′/i
    nucl_regex = /(([ACGTU]{3,} ?)+([ACGTU]{1,2} )?)/
    text.scan(dna_regex) { |m|
      @sequences << {
        position: Regexp.last_match.offset(0).first,
        type:    'nucleotide',
        sequence: $1.strip
      }
    }
    text.scan(nucl_regex) { |m|
      if ($1.strip.length >= 10)
        @sequences << {
          position: Regexp.last_match.offset(0).first,
          type:    'nucleotide',
          sequence: $1.strip
        }
      end
    }
  end

  def parse_proteins(text)
    protein_regex = /(((Ala|Arg|Asn|Asp|Cys|Glu|Gln|Gly|His|Ile|Leu|Lys|Met|Phe|Pro|Ser|Thr|Trp|Tyr|Val|Xaa) ?){3,})/i
    text.scan(protein_regex) { |m|
      @sequences << {
        position: Regexp.last_match.offset(0).first,
        type:     'protein',
        sequence: $1.gsub(/([A-Z]{3})/i, '\1 ').gsub(/ (?=( |$))/,'')
      }
    }
  end

  def parse_amino_acids(text)
    amino_regex = /(?:[Pp]eptides?|[Pp]roteins?|[Ss]equences?)[:, ]*([A-Z]{6,})/
    text.scan(amino_regex) { |m|
      @sequences << {
        position: Regexp.last_match.offset(0).first,
        type:     'protein',
        sequence: $1.strip
      }
    }
  end

  def order_sequences
    @sequences.sort!{|x,y| x[:position] <=> y[:position]}
    @sequences.uniq!{|x| x[:sequence]}
    @sequences.each_with_index {|x, i| x[:position] = i + 1}
  end

  def parse_html(url)
    doc = Nokogiri::HTML(open(url))

    if (title = doc.css("invention-title"))
      @title = title.text
      puts @title
    end

    if (patent_number = doc.css("span.patent-number"))
      publication_number_from_string(patent_number.text)
    end

    if (patentBibData = doc.css("table.patent-bibdata"))
      patentBibData.css("tr").each do |tr|
        unless (tds = tr.css("td")).empty?
          case tds[0].text.strip
          when "Publication number"
            if tr["class"].to_s.empty?
              publication_number_from_string(tds[1].text)
            elsif tr["class"] == "patent-bibdata-list-row alternate-patent-number"
              tds[1].css("span.patent-bibdata-value-list span.patent-bibdata-value").each do |also_num|
                @alternate_numbers << also_num.text.gsub(/,/,'').strip
              end
            end
          when "Publication type"
            @publication_type = tds[1].text
          when "Application number"
            @application_number = tds[1].text
          when "Publication date"
            @publication_date = Date.parse(tds[1].text).to_s
          when "Filing date"
            @filing_date = Date.parse(tds[1].text).to_s
          when "Priority date"
            @priority_date = Date.parse(tds[1].text).to_s
            puts @priority_date
          when "Also published as"
            tds[1].css("span.patent-bibdata-value-list span.patent-bibdata-value").each do |also_num|
              @published_as << also_num.text.gsub(/,/,'').strip
            end
          when "Inventors"
            tds[1].css("span.patent-bibdata-value-list span.patent-bibdata-value").each do |also_num|
              @inventors << also_num.text.strip.gsub(/\s*,\s*$/,'')
            end
          when "Original Assignee"
            tds[1].css("span.patent-bibdata-value-list span.patent-bibdata-value").each do |also_num|
              @assignees << also_num.text.strip.gsub(/\s*,\s*$/,'')
            end
          end
        end
      end
    end

    if (abstract = doc.css("abstract"))
      @abstract = abstract.text.strip
    end

    if !(description = doc.css("ul.description")).empty?
      @description = description.text.strip
    else
      description = doc.css("div.description")
      @description = description.text.strip
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

    if (references = doc.css("div.patent-section"))
      references.each do |reference|
        if reference["class"] == "patent-section patent-tabular-section"
          if (title = reference.css("div.patent-section-header span.patent-section-title"))
            case title.text
            when "Patent Citations"
              footer = reference.css("div.patent-section-footer")
              reference.css("table.patent-data-table tr").each do |tr|
                tds = tr.css("td")
                unless tds.to_s.empty?
                  @patent_citations << {
                    "Citing Patent": tds[0].text,
                    "Filing date": tds[1].text,
                    "Publication date": tds[2].text,
                    "Applicant": tds[3].text,
                    "Title": tds[4].text,
                    "Note": (tds[0].text =~ /\*/ ? footer.text : "")
                  }
                end
              end
            when "Non-Patent Citations"
              footer = reference.css("div.patent-section-footer")
              reference.css("table.patent-data-table tr").each do |tr|
                tds = tr.css("td")
                unless tds.to_s.empty?
                  @non_patent_citations << {
                    "Number": tds[0].text,
                    "Title": tds[2].text
                  }
                end
              end
            when "Referenced by"
              footer = reference.css("div.patent-section-footer")
              reference.css("table.patent-data-table tr").each do |tr|
                tds = tr.css("td")
                unless tds.to_s.empty?
                  @referenced_by << {
                    "Citing Patent": tds[0].text,
                    "Filing date": tds[1].text,
                    "Publication date": tds[2].text,
                    "Applicant": tds[3].text,
                    "Title": tds[4].text,
                    "Note": (tds[0].text =~ /\*/ ? footer.text : "")
                  }
                end
              end
            when "Classifications"
              reference.css("table.patent-data-table tr").each do |tr|
                if tr["class"].to_s.empty?
                  tds = tr.css("td")
                  unless tds.to_s.empty?
                    @classifications << { "#{tds[0].text}": tds[1].text.to_s.split(/, */) }
                  end
                end
              end
            when "Legal Events"
              reference.css("table.patent-data-table tr").each do |tr|
                tds = tr.css("td")
                unless tds.to_s.empty?
                  description = []
                  tds[3].css("div.nested-key-value").each do |div|
                    description << {
                      "#{div.css("span.nested-key").text.gsub(/\s*\:\s*/,'')}": div.css("span.nested-value").text
                    }
                  end
                  @legal_events << {
                    "Date": tds[0].text,
                    "Code": tds[1].text,
                    "Event": tds[2].text,
                    "Description": description
                  }
                end
              end
            end
          end
        end
      end
    end

    parse_sequences

    puts @sequences
  end

  def to_ice
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.wogene(action: "new", date: Date.today.to_s.gsub(/\-/,''), language: (@filing_language =~ /english/i ? 'en' : 'fr')) do
        xml.biblio do
        end
        xml.sequences do
        end
      end
    end
    builder.to_xml
  end

end

p = Patent.new(filename: 'http://www.google.com/patents/US7523026')

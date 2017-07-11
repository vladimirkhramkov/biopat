#!/usr/bin/env ruby

require 'dotenv/load'
require 'nokogiri'
require 'open-uri'
require 'date'

class Patent
    attr_accessor :number,:country,:english_title,:french_title
    attr_accessor :ipc,:inventors,:owners,:applicants,:agent
    attr_accessor :issued,:pct_filing_date,:pct_publication_date
    attr_accessor :examination_date,:licence_availability,:filing_language
    attr_accessor :pct,:pct_filing_number,:ipn,:national_entry
    attr_accessor :application_priority_data
    attr_accessor :english_abstract, :french_abstract
    attr_accessor :claims

    def initialize(args)
	self.ipc = []
	self.inventors = []
	self.owners = []
	self.applicants = []
	self.application_priority_data = []
	self.claims = []

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

    def publication_date
	@issued.to_s.empty? ? @pct_publication_date : @issued
    end

    def to_st36
	builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') { |xml|
	    xml.doc.create_internal_subset(
		'wo-patent-document',
		nil,
		'wo-patent-document-v1-3.dtd'
	    )
	    xml.send("wo-patent-document",
		id: "wo-patent-document",
		file: "#{number}.xml",
		country: @country,
		docnumber: @number,
		kind: "A1",
		:"date-published" => @pct_publication_date,
		:"dtd-version" => "v1.3 2005-01-01",
		lang: (@filing_language =~ /english/i ? 'en' : 'fr')
	    ) do
		xml.send("bibliographic-data") do
		end
		xml.send("abstract") do
		end
		xml.send("description") do
		    xml.send("invention-title") do
		    end
		end
		xml.send("claims") do
		end
	    end
	}
	builder.to_xml
    end

    def to_bsp
	builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') { |xml|
	    xml.wogene(action: "new", date: Date.today.to_s.gsub(/\-/,''), language: (@filing_language =~ /english/i ? 'en' : 'fr')) do
		xml.biblio do
		end
		xml.sequences do
		end
	    end
	}
	builder.to_xml
    end

    def seq_filename
	"CA#{@number}-#{to_date(publication_date())}-S00001.SEQ"
    end

    def parse_html(url)
    doc = Nokogiri::HTML(open(url))
    if (patentSummaryTable = doc.css("table#patentSummaryTable"))
	patentSummaryTable.css("tr").each do |tr|
	    if !tr.css("th#patentNum").empty?
		@country, @number = tr.css("td strong").text.strip.split(/\s+/)
	    elsif !tr.css("th#EnglishTitle").empty?
		@english_title = tr.css("td").text.strip
	    elsif !tr.css("th#FrenchTitle").empty?
		@french_title = tr.css("td").text.strip
	    end
	end
    end

    if (patentDetailsTable = doc.css("table#patentDetailsTable"))
	patentDetailsTable.css("tr").each do |tr|
	    if !tr.css("th#intlClass").empty?
		if (ul = tr.css("td ul"))
		    ul.css("li").each do |li|
			@ipc << li.text.gsub(/\s\s+/,' ').strip
		    end
		end
	    elsif !tr.css("th#inventors").empty?
		if (ul = tr.css("td ul"))
		    ul.css("li").each do |li|
			@inventors << li.text.gsub(/\s\s+/,' ').strip
		    end
		end
	    elsif !tr.css("th#owners").empty?
		if (ul = tr.css("td ul"))
		    ul.css("li").each do |li|
			@owners << li.text.gsub(/\s\s+/,' ').strip
		    end
		end
	    elsif !tr.css("th#applicants").empty?
		if (ul = tr.css("td ul"))
		    ul.css("li").each do |li|
			@applicants << li.text.gsub(/\s\s+/,' ').strip
		    end
		end
	    elsif !tr.css("th#agent").empty?
		if (td = tr.css("td"))
		    @agent = td.text.gsub(/\s\s+/,' ').strip
		end
	    elsif !tr.css("th#issued").empty?
		if (td = tr.css("td"))
		    @issued = td.text.gsub(/\s\s+/,' ').strip
		end
	    elsif !tr.css("th#filingDate").empty?
		if (td = tr.css("td"))
		    @pct_filing_date = td.text.gsub(/\s\s+/,' ').strip
		end
	    elsif !tr.css("th#pubDate").empty?
		if (td = tr.css("td"))
		    @pct_publication_date = td.text.gsub(/\s\s+/,' ').strip
		end
	    elsif !tr.css("th#examDate").empty?
		if (td = tr.css("td"))
		    @examination_date = td.text.gsub(/\s\s+/,' ').strip
		end
	    elsif !tr.css("th#lic").empty?
		if (td = tr.css("td"))
		    @licence_availability = td.text.gsub(/\s\s+/,' ').strip
		end
	    elsif !tr.css("th#lang").empty?
		if (td = tr.css("td"))
		    @filing_language = td.text.gsub(/\s\s+/,' ').strip
		end
	    end
	end
    end

    if (pctTable = doc.css("table#pctTable"))
	pctTable.css("tr").each do |tr|
	    if !tr.css("th#pct").empty?
		if (td = tr.css("td"))
		    @pct = td.text.gsub(/\s\s+/,' ').strip
		end
	    elsif !tr.css("th#pctNum").empty?
		if (td = tr.css("td"))
		    @pct_filing_number = td.text.gsub(/\s\s+/,' ').strip
		end
	    elsif !tr.css("th#pubNum").empty?
		if (td = tr.css("td"))
		    @ipn = td.text.gsub(/\s\s+/,' ').strip
		end
	    elsif !tr.css("th#national").empty?
		if (td = tr.css("td"))
		    @national_entry = td.text.gsub(/\s\s+/,' ').strip
		end
	    end
	end
    end

    if (appPriorityTable = doc.css("table#appPriorityTable"))
	appPriorityTable.css("tr").each do |tr|
	    a = tr.css("td").map{|e| e.text.strip}
	    if a.count == 3
		@application_priority_data << { number: a[0], country: a[1], date: a[2] }
	    end
	end
    end

    if (abstracts = doc.css("div#tabs1_2"))
	abstracts_hash = Hash[*(abstracts.css("h4,p").map{|e| e.text})]
	@english_abstract = abstracts_hash["English Abstract"]
	@french_abstract = abstracts_hash["French Abstract"]
    end

    if (claims = doc.css("div#tabs1_3 div"))
	claims_array = claims.inner_html.gsub(/(<br>)+/,"\n").split(/\n+([\d\,\-\ ]+)\./).map{|e| e.strip.gsub(/[ \t\n]+/,' ')}
	claims_array.shift
	claims_grouped = claims_array.each_slice(2).to_a
	claims_grouped.each_cons(2){|x,y|
	    if !y.nil?
		if (y[1].empty? || y[1] =~ /^\s*\-\s*\d+\s*\-\s*$/)
		    x[1]=x[1]+" #{y[0]}."
		    y[1] = ""
		end
	    end
	}
	@claims = claims_grouped.map{|e| 
	    unless e[1].empty?
		{ num: e[0], text: e[1]}
	    end
	}.compact
    end
    end
end

def download_s3(num)
    n = num.to_i
    filename = "#{n}.html"
    unless File.exist?(filename)
	if ENV['S3_BUCKET']
	    system("aws s3 cp #{ENV['S3_BUCKET']}/#{n}.html.gz ./")
	end
	if File.exist?("#{n}.html.gz")
    	    system("gzip -d #{n}.html.gz")
	end
    end
    filename
end

if ARGV[0]
    filename = download_s3(ARGV[0])
    if File.exist?(filename)
	p = Patent.new(filename: filename)
	puts p.seq_filename
    end
end


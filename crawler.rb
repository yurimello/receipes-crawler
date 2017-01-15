#! /usr/bin/env ruby

require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'json'
require 'pry'

class Crawler
  BASE_URL = 'http://www.tudogostoso.com.br'

  USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.95 Safari/537.36'

  CATEGORIES = [
    'carnes', 'aves', 'peixes-e-frutos-do-mar', 'saladas-molhos-e-acompanhamentos',
    'sopas', 'massas', 'bebidas', 'doces-e-sobremesas', 'lanches', 'bolos-e-tortas-doces',
    'alimentacao-saudavel'
  ]

  ENDPOINT = 'receitas-populares'


  attr_reader :receipes, :receipe_links, :html_doc
  def initialize
    @receipes = []

    @receipe_links = []
    @html_doc = nil

    @category = nil
    @receipe_uri = nil
  end

  def crawl
    CATEGORIES.each do |category|
      @category = category

      uri = "#{BASE_URL}/#{category}/#{ENDPOINT}"
      response = open(uri, "User-Agent" => USER_AGENT).read
      @html_doc = Nokogiri::HTML(response)
      get_links

      get_receipes
    end
  end

  def get_receipes
    @receipe_links.each do |receipe_link|
      @receipe_uri = receipe_link
      begin
        response = open(receipe_link, "User-Agent" => USER_AGENT).read
      rescue
        sleep 3
        response = open(receipe_link, "User-Agent" => USER_AGENT).read
      end
      @html_doc = Nokogiri::HTML(response)
      receipes << get_receipe
    end
  end


  def get_receipe
    receipe = {}
    receipe[:name] = get_receipe_name
    receipe[:image] = get_receipe_image
    receipe[:category] = @category
    receipe[:uri] = @receipe_uri
    receipe[:receipe_info] = get_receipe_info
    receipe[:ingredients] = get_ingredients
    receipe[:instructions] = get_instructions

    receipe
  end

  def get_receipe_name
    @html_doc.css('div.recipe-title h1').text.strip
  end

  def get_receipe_image
    begin
      @html_doc.css('a.picframe img').attribute('src').value
    rescue
      ''
    end
  end

  def get_receipe_info
    receipe_info_hsh = {}
    receipe_info = @html_doc.css('div.info')
    receipe_info_hsh[:preptime] = get_preptime(receipe_info)
    receipe_info_hsh[:receipe_yield] = get_receipe_yield(receipe_info)
    receipe_info_hsh
  end

  def get_preptime(receipe_info)
    begin
      receipe_info.css('span.preptime').text.strip
    rescue
      ''
    end
  end

  def get_receipe_yield(receipe_info)
    begin
      receipe_info.css('data.yield').text.strip
    rescue
      ''
    end
  end

  def get_ingredients
    ingredients = []
    @html_doc.css('div.ingredients-box span.p-ingredient').each do |ingredient|
      ingredients << get_ingredient(ingredient)
    end
    ingredients
  end

  def get_ingredient(raw_ingredient)
    ingredient = {}
    raw_ingredient = raw_ingredient.text.strip

    if raw_ingredient =~ /de/
      parsed_ingredient = raw_ingredient.match(/^(\d*\/?\d*)(.*)de(.*)$/)
      ingredient[:lenght] = parsed_ingredient[1].strip
      ingredient[:unity_type] = parsed_ingredient[2].strip
      ingredient[:name] = parsed_ingredient[3].strip
    else
      parsed_ingredient = raw_ingredient.match(/^(\d*\/?\d*)(.*)$/)
      ingredient[:lenght] = parsed_ingredient[1].strip
      ingredient[:unity_type] = ''
      ingredient[:name] = parsed_ingredient[2].strip
    end

    ingredient
  end

  def get_instructions
    instructions = []
    @html_doc.css('div.instructions span').each_with_index do |instruction, index|
      instructions << {
        text: instruction.text.strip,
        order: index + 1
      }
    end
    instructions
  end


  def get_links
    @html_doc.css('div.listing ul a').each do |link|
      @receipe_links << "#{BASE_URL}#{link['href']}"
    end
  end
end

crawler = Crawler.new
crawler.crawl
file = File.open('receipes.json', 'w')
file.write(crawler.receipes.to_json)
file.close

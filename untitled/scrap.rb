# frozen_string_literal: true

require 'curb'
require 'nokogiri'
require 'csv'

def get_html(url)
  user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36'
  response = Curl.get(url) do |http|
    http.headers['User-Agent'] = user_agent
  end
  return Nokogiri::HTML(response.body) if response.status == '200'

  false
end

def get_products_links(url)
  counter = 1
  links = []
  link = url
  loop do
    link = url + "?p=#{counter}" if counter > 1
    content = get_html(link)
    return links if content == false

    puts "Getting products links from #{link}"
    links += content.xpath("//ul[@id='product_list']/li/div/div[2]/div[1]/a/@href")
    counter += 1
  end
  links
end

def extract_product_data_from_page(url)
  products = []
  puts "Extracting products from #{url}"
  content = get_html(url).xpath("//div[@id='center_column']")
  img_link = content.xpath("//img[@id='bigpic']/@src")
  name = content.xpath("//h1[@class='product_main_name']/text()").text
  if !content.xpath("//div[@id='attributes']").empty?
    weight = content.xpath(
      "//span[@class='radio_label']/text()"
    )
    price = content.xpath(
      "//span[@class='price_comb']/text()"
    )
    (0..price.size - 1).each do |i|
      products.push(
        ["#{name}-#{weight[i]}", price[i].to_s, img_link.to_s]
      )
    end
  else
    price = content.xpath("//span[@id='our_price_display']/text()")
    products.push(
      [name, price.to_s, img_link.to_s]
    )
  end
  products
end

def export_csv(file, data)
  puts "Start export to #{file}"
  CSV.open(file, 'w', write_headers: true, headers: %w[Name Price Image]) do |csv|
    data.each do |product|
      csv << product
    end
  end
  puts " #{file} ready"
end

def main(url, file_name)
  all_products = []
  links = get_products_links(url)
  threads = []
  links.each do |link|
    threads << Thread.new(link) do |uri|
      Thread.current['myproducts'] = extract_product_data_from_page(uri)
      sleep(rand(2..5))
      puts "Done #{uri}"
    end
  end

  threads.each do |thr|
    thr.join
    all_products += thr['myproducts']
  end

  export_csv(file_name, all_products)
end

if ARGV.length < 2
  puts 'Too few arguments'
  exit
else
  main(ARGV[0], ARGV[1])
end

require 'curb'
require 'nokogiri'
require 'csv'


$user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.121 Safari/537.36"

def extract_product_data_from_page(url)
  puts "Extracting data from %s"%[url]
  response = Curl.get(url) do |http|
    http.headers['User-Agent'] = $user_agent
  end
  html_content = Nokogiri::HTML(response.body_str).xpath("//body/div/div/div/div/div/div/div/div[2]")
  img_link = html_content.xpath("//div/div[2]/span/img[@id='bigpic']/@src")
  name = html_content.xpath("//div[2]/div/div[2]/h1[@class='product_main_name']/text()")
  product_variations_blocks = html_content.xpath(
      "//body/div/div/div/div/div/div/div/div[2]/div[2]/form/div/div[2]/div/fieldset/div/ul/li/label"
  )
  weight, price = product_variations_blocks.xpath("//span[@class='radio_label']/text()"),
      product_variations_blocks.xpath("//span[@class='price_comb']/text()")
  products = []
  (0..weight.size-1).each { |i|
    products.push(
        [(name.to_s.gsub('&amp;', '&') + '-' + weight[i].to_s), price[i].to_s, img_link.to_s]
    )
  }
  puts "OK"
  products
end


def get_product_links(url)
  $links = []
  $count = 1
  puts "Getting links of products of this category"
  begin
    if $count == 1
      response = Curl.get(url) do |curl|
        curl.headers['User-Agent'] = $user_agent
      end
    else
      response = Curl.get(url + '?p=%d' %[$count]) do |curl|
        curl.headers['User-Agent'] = $user_agent
      end
    end
    html = Nokogiri::HTML(response.body_str)
    links_on_page = html.xpath("//body/div/div/div/div/div/div[2]/ul/li/div/div[2]/div[1]/a/@href")
    $links += links_on_page
    $count += 1
  end while response.status == '200'
  puts "There were %d products if this category"%[$links.length]
  $links
  end


def export_csv(file, data)
  puts "Start export to %s"%[file]
  CSV.open(file, 'w', write_headers: true, headers: %w[Name Price Image]) do |csv|
    data.each do |product|
      csv << product
    end
  end
  puts "Finished"
end


def main(url, file_name)
  all_products = []
  start = Time.now.utc
  links = get_product_links(url)
  while links.length != 0
    random_link_idx = rand(0..links.length-1)
    all_products += extract_product_data_from_page(links[random_link_idx])
    links.delete_at(random_link_idx)
    sleep(rand(2..10))
  end
  export_csv(file_name, all_products)
  puts "-----------------------------------------------------\nElapsed time %s seconds"%(
  (Time.now.utc-start).round(2)
  )
end


if ARGV.length < 2
  puts "Too few arguments"
  exit
else
  main(ARGV[0], ARGV[1])
end
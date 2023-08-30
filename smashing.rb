require 'nokogiri'
require 'open-uri'
require 'down'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: smashing.rb [options]"

  opts.on("--month MONTH", "Specify the month in the format MMYYYY") do |month|
    options[:month] = month
  end

  opts.on("--resolution RESOLUTION", "Specify the resolution (e.g., 640x480)") do |resolution|
    options[:resolution] = resolution
  end
end.parse!

def fetch_wallpaper_links(base_url)
  begin
    html = URI.open(base_url).read
    doc = Nokogiri::HTML(html)
    doc.css('a[href$=".jpg"], a[href$=".png"]').map { |a| a['href'] }
  rescue OpenURI::HTTPError, StandardError => e
    puts "Error fetching or parsing the page: #{e.message}"
    nil
  end
end

def download_wallpaper(base_url, url, resolution, download_directory)
  wallpaper_url = URI.join(base_url, url).to_s
  wallpaper_filename = File.basename(wallpaper_url)
  wallpaper_path = File.join(download_directory, wallpaper_filename)

  resolution_pattern = /(\d+x\d+)/
  image_resolution = wallpaper_filename.match(resolution_pattern)&.[](1)

  if image_resolution == resolution
    begin
      Down.download(wallpaper_url, destination: wallpaper_path)
      puts "Downloaded: #{wallpaper_filename}"
    rescue
      puts "Failed to download: #{wallpaper_filename}"
    end
  end
end

def download_wallpapers(year, month, resolution)
  calc_month = month == 1 ? 12 : month - 1
  calc_year = month == 1 ? year - 1 : year
  base_url = "https://www.smashingmagazine.com/#{calc_year}/#{(calc_month).to_s.rjust(2, '0')}" \
             "/desktop-wallpaper-calendars-#{Date::MONTHNAMES[month].downcase}-#{year}/"
  wallpaper_links = fetch_wallpaper_links(base_url)

  if wallpaper_links.empty?
    puts "No wallpapers found for the specified month and year."
    return
  end

  download_directory = "#{year}-#{month.to_s.rjust(2, '0')}_#{resolution}_wallpapers"
  Dir.mkdir(download_directory) unless Dir.exist?(download_directory)

  wallpaper_links.each do |link|
    download_wallpaper(base_url, link, resolution, download_directory)
  end
end

if options[:month] && options[:resolution]
  month = options[:month][0, 2]
  year = options[:month][2, 4]
  resolution = options[:resolution]

  download_wallpapers(year.to_i, month.to_i, resolution)
else
  puts "Usage: ruby script.rb --month MMYYYY --resolution 640x480"
end

# frozen_string_literal: true

require_relative '../smashing'
require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

describe 'Smashing Wallpaper Downloader' do
  let(:base_url) { 'https://www.smashingmagazine.com/2023/01/desktop-wallpaper-calendars-january-2023/' }
  let(:resolution) { '640x480' }
  let(:download_directory) { '2023-01_640x480_wallpapers' }

  after do
    Dir.rmdir(download_directory)
  end

  describe 'fetch_wallpaper_links' do
    before do
      stub_request(:get, base_url)
        .to_return(body: <<-HTML
          <a href="wallpaper1.jpg">Wallpaper 1</a>
          <a href="wallpaper2.png">Wallpaper 2</a>
        HTML
                  )

      Dir.mkdir('2023-01_640x480_wallpapers') unless Dir.exist?('2023-01_640x480_wallpapers')
    end

    it 'returns an array of wallpaper links' do
      links = fetch_wallpaper_links(base_url)
      expect(links).to include('wallpaper1.jpg', 'wallpaper2.png')
    end

    it 'handles errors gracefully' do
      stub_request(:get, base_url).to_raise(OpenURI::HTTPError.new('404 Not Found', nil))

      expect { fetch_wallpaper_links(base_url) }.to output(/Error fetching or parsing the page/).to_stdout
    end
  end

  describe 'download_wallpaper' do
    let(:download_directory) { '2023-01_640x480_wallpapers' }
    let(:url) { 'mar-22-spring-is-coming-cal-640x480.jpg' }
    let(:wallpaper_path) { File.join(download_directory, url) }

    before do
      Dir.mkdir('2023-01_640x480_wallpapers') unless Dir.exist?('2023-01_640x480_wallpapers')
    end

    after do
      File.delete(wallpaper_path) if File.exist?(wallpaper_path)
    end

    it 'downloads a wallpaper matching the resolution' do
      stub_request(:get, File.join(base_url, url))
        .to_return(body: 'Downloaded: mar-22-spring-is-coming-cal-640x480.jpg')

      allow(Down).to receive(:download).and_return(File.new(wallpaper_path, 'w'))

      download_wallpaper(base_url, url, resolution, download_directory)
      expect(File.exist?(wallpaper_path)).to be_truthy
    end

    it 'skips downloading if the resolution does not match' do
      stub_request(:get, File.join(base_url, url))
        .to_return(body: 'Sample Wallpaper Content')

      download_wallpaper(base_url, url, '800x600', download_directory)

      wallpaper_path = File.join(download_directory, url)
      expect(File).not_to exist(wallpaper_path)
    end

    it 'handles errors gracefully' do
      stub_request(:get, File.join(base_url, url)).to_raise(StandardError)

      expect { download_wallpaper(base_url, url, resolution, download_directory) }
        .to output(/Failed to download/).to_stdout
    end
  end

  describe 'download_wallpapers' do
    let(:year) { 2023 }
    let(:month) { 1 }
    let(:resolution) { '640x480' }
    let(:base_url) { 'https://www.smashingmagazine.com/2022/12/desktop-wallpaper-calendars-january-2023/' }
    let(:download_directory) { "#{year}-#{month.to_s.rjust(2, '0')}_#{resolution}_wallpapers" }

    before do
      allow(self).to receive(:fetch_wallpaper_links).and_return(['wallpaper1.jpg'])
      allow(self).to receive(:download_wallpaper).with(base_url, 'wallpaper1.jpg', resolution, download_directory)

      Dir.mkdir(download_directory) unless Dir.exist?(download_directory)
    end

    it 'downloads wallpapers for the specified month and year' do
      download_wallpapers(year, month, resolution)

      expect(self).to have_received(:download_wallpaper).with(base_url, 'wallpaper1.jpg', resolution, anything)
    end

    it 'handles the case when no wallpapers are found' do
      allow(self).to receive(:fetch_wallpaper_links).and_return([])

      download_wallpapers(year, month, resolution)

      expect(self).not_to have_received(:download_wallpaper)
    end
  end
end

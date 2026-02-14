require 'mini_magick'
require 'selenium-webdriver'
require 'base64'
require 'thread'
require 'tempfile'
require 'fileutils'
require 'uri'

module TRMNLP
  class ScreenGenerator
    # Browser pool management for efficient resource usage
    class BrowserPool
      def initialize(max_size: 2)
        @drivers = []
        @available = Queue.new
        @mutex = Mutex.new
        @max_size = max_size
        @shutdown = false

        at_exit { shutdown }
      end

      def with_driver
        driver = nil

        begin
          driver = checkout_driver
          yield driver
        ensure
          checkin_driver(driver) if driver
        end
      end

      def shutdown
        @mutex.synchronize do
          return if @shutdown
          @shutdown = true

          @drivers.each do |driver|
            driver.quit rescue nil
          end

          @drivers.clear
        end
      end

      private

      def checkout_driver
        driver = @available.pop(true) rescue nil

        if driver.nil?
          @mutex.synchronize do
            if @drivers.size < @max_size
              driver = create_driver
              @drivers << driver
            end
          end
        end

        driver ||= @available.pop

        begin
          # Ping the driver
          driver.title
          driver
        rescue
          @mutex.synchronize do
            @drivers.delete(driver)
            driver = create_driver
            @drivers << driver
          end
          driver
        end
      end

      def checkin_driver(driver)
        return if @shutdown
        @available.push(driver)
      end

      def create_driver
        options = Selenium::WebDriver::Firefox::Options.new
        options.add_argument('--headless')
        options.add_argument('--disable-web-security')
        options.add_preference('gfx.text.disable-aa', true)
        options.add_preference('gfx.text.subpixel-position.force-disabled', true)

        driver = Selenium::WebDriver.for(:firefox, options: options)
        # Set a default window size that will be consistent
        driver.manage.window.maximize
        driver
      end
    end

    @@browser_pool = BrowserPool.new

    def initialize(html, opts = {})
      self.input = html
      self.image = !!opts[:image]

      # Accept optional rendering parameters (width/height/color depth/dark mode)
      @requested_width = opts[:width]
      @requested_height = opts[:height]
      @requested_color_depth = opts[:color_depth]
    end

    attr_accessor :input, :output, :image

    def process
      convert_to_image
      image ? mono_image(output) : mono(output)
      output
    end

    private

    def convert_to_image
      retry_count = 0

      begin
        @@browser_pool.with_driver do |driver|
          # determine dimensions of toolbars, etc
          borders = driver.execute_script(<<~JS)
            return {
              width: window.outerWidth - window.innerWidth,
              height: window.outerHeight - window.innerHeight
            }
          JS

          window_width = width + borders['width']
          window_height = height + borders['height']
          driver.manage.window.size = Selenium::WebDriver::Dimension.new(window_width, window_height)
          
          sleep(0.1)

          prepare_page(driver)

          self.output = Tempfile.new(['screenshot', '.png'])
          driver.save_screenshot(output.path)
          output.close
        end
      rescue Selenium::WebDriver::Error::TimeoutError,
            Selenium::WebDriver::Error::WebDriverError => e
        retry_count += 1
        retry if retry_count <= 1
        raise
      end
    end

    def prepare_page(driver)
      driver.navigate.to('about:blank')

      driver.execute_script(<<~JS, input)
        document.open();
        document.write(arguments[0]);
        document.close();
      JS

      Selenium::WebDriver::Wait.new(timeout: 5).until do
        driver.execute_script('return document.readyState') == 'complete'
      end

      # Wait for fonts (prevents layout shifts)
      driver.execute_script('return document.fonts && document.fonts.ready')

      driver.execute_script(<<~JS)
        document.documentElement.style.overflow = 'hidden';
        document.body.style.overflow = 'hidden';
      JS
    end
      
    def convert_with_mini_magick(img, depth)
      tmp = Tempfile.new(['mono', '.png'])
      tmp.close

      levels = 2**depth

      MiniMagick::Tool::Convert.new do |m|
        m << img.path
        m.colorspace 'Gray'
        m.dither 'FloydSteinberg'

        yield(m, depth, levels)

        m.depth depth
        m.define "png:bit-depth=#{depth}"
        m.strip
        m << tmp.path
      end

      FileUtils.mv(tmp.path, img.path, force: true)
    end

    def mono(img)
      depth = [[color_depth.to_i, 1].max, 8].min

      convert_with_mini_magick(img, depth) do |m, d, levels|
        m.posterize levels
        m.colors levels
        m.type 'Bilevel' if d == 1
      end
    end

    def mono_image(img)
      depth = [[color_depth.to_i, 1].max, 8].min

      convert_with_mini_magick(img, depth) do |m, d, levels|
        if d == 1
          # For true 1-bit, use a halftone/remap and bilevel output
          m.remap 'pattern:gray50'
          m.posterize 2
          m.colors 2
          m.type 'Bilevel'
        else
          m.posterize levels
          m.colors levels
        end
      end
    end


    def width
      @requested_width || 800
    end

    def height
      @requested_height || 480
    end

    def color_depth
      return @requested_color_depth if @requested_color_depth

      # Try to infer color depth from the rendered HTML's screen classes
      if input && input.match(/screen--(\d+)bit/)
        return $1.to_i
      end

      1
    end
  end
end

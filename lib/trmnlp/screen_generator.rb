require 'mini_magick'
require 'puppeteer-ruby'
require 'base64'
require 'thread'

module TRMNLP
  class ScreenGenerator
    # Browser pool management for efficient resource usage
    class BrowserPool
      def initialize(max_size: 2)
        @browsers = []
        @available = Queue.new
        @mutex = Mutex.new
        @max_size = max_size
        @shutdown = false
        
        # Register cleanup on exit
        at_exit { shutdown }
      end
      
      def with_page
        browser = nil
        page = nil
        
        begin
          browser = checkout_browser
          page = browser.new_page
          yield page
        ensure
          # Clean up page but keep browser alive
          page&.close rescue nil
          checkin_browser(browser) if browser
        end
      end
      
      def shutdown
        @mutex.synchronize do
          return if @shutdown
          @shutdown = true
          
          # Close all browsers
          @browsers.each do |browser|
            browser.close rescue nil
          end
          @browsers.clear
        end
      end
      
      private
      
      def checkout_browser
        # Try to get an available browser
        browser = @available.pop(true) rescue nil
        
        # If no browser available and we haven't reached max size, create a new one
        if browser.nil?
          @mutex.synchronize do
            if @browsers.size < @max_size
              browser = create_browser
              @browsers << browser
            end
          end
        end
        
        # If still no browser, wait for one to become available
        browser ||= @available.pop
        
        # Verify browser is still alive
        begin
          browser.targets # Simple check to see if browser responds
          browser
        rescue
          # Browser is dead, create a new one
          @mutex.synchronize do
            @browsers.delete(browser)
            browser = create_browser
            @browsers << browser
          end
          browser
        end
      end
      
      def checkin_browser(browser)
        return if @shutdown
        @available.push(browser)
      end
      
      def create_browser
        Puppeteer.launch(
          product: 'firefox',
          headless: true,
          args: [
            "--window-size=800,480",
            "--disable-web-security"
          ]
        )
      end
    end
    
    # Class-level browser pool shared across all instances
    @@browser_pool = BrowserPool.new
    
    def initialize(html, opts = {})
      self.input = html
      self.image = !!opts[:image]
    end

    attr_accessor :input, :output, :image, :processor, :img_path

    def process
      convert_to_image
      image ? mono_image(output) : mono(output)
      output
    end

    private

    def convert_to_image
      retry_count = 0
      
      begin
        @@browser_pool.with_page do |page|
          # Configure page
          page.viewport = Puppeteer::Viewport.new(width: width, height: height)
          
          # Set content with appropriate wait strategy
          page.set_content(input, timeout: 10000)
          
          # Hide scrollbars
          page.evaluate(<<~JAVASCRIPT)
            () => {
              document.getElementsByTagName('html')[0].style.overflow = "hidden";
              document.getElementsByTagName('body')[0].style.overflow = "hidden";
            }
          JAVASCRIPT
          
          # Take screenshot
          self.output = Tempfile.new(['screenshot', '.png'])
          page.screenshot(path: output.path, type: 'png')
        end
      rescue Puppeteer::TimeoutError, Puppeteer::FrameManager::NavigationError => e
        retry_count += 1
        if retry_count <= 1
          retry
        else
          puts "ERROR -> ScreenGenerator#convert_to_image -> #{e.message}"
          raise
        end
      end
    end

    def mono(img)
      MiniMagick::Tool::Convert.new do |m|
        m << img.path
        m.monochrome # Use built-in smart monochrome dithering (but it's not working as expected)
        m.depth(color_depth) # Should be set to 1 for 1-bit output
        m.strip # Remove any additional metadata
        m << img.path
      end
    end

    def mono_image(img)
      # Convert to monochrome bitmap with proper dithering
      # This implementation works with both ImageMagick 6.x and 7.x
      MiniMagick::Tool::Convert.new do |m|
        m << img.path
        
        # First convert to grayscale to ensure proper channel handling
        m.colorspace << 'Gray'
        
        # Apply Floyd-Steinberg dithering for better quality
        m.dither << 'FloydSteinberg'
        
        # Reduce to 2 colors (black and white)
        m.colors << 2
        
        # Remap to a 50% gray pattern for better dithering
        m.remap << 'pattern:gray50'
        
        # Set the image type to bilevel (1-bit black and white)
        m.type << 'Bilevel'
        
        # Set color depth to 1 bit
        m.depth << color_depth
        
        # Remove any metadata to reduce file size
        m.strip
        
        m << img.path
      end
    end

    def width = 800

    def height = 480

    def color_depth = 1
  end
end

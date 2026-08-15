# frozen_string_literal: true

module TRMNLP
  class BrowserPool
    def initialize(driver_factory:, max_size: 2)
      @driver_factory = driver_factory
      @max_size = max_size
      @drivers = []
      @available = Queue.new
      @mutex = Mutex.new
      @shutdown = false

      at_exit { shutdown }
    end

    def with_driver
      driver = checkout
      yield driver
    ensure
      checkin(driver) if driver
    end

    def shutdown
      @mutex.synchronize do
        return if @shutdown

        @shutdown = true
        @drivers.each do |driver|
          driver.quit
        rescue StandardError
          nil
        end
        @drivers.clear
      end
    end

    private

    def checkout
      driver = acquire
      healthy?(driver) ? driver : recycle(driver)
    end

    def acquire
      pop_available || build_new || @available.pop
    end

    def pop_available
      @available.pop(true)
    rescue StandardError
      nil
    end

    def build_new
      @mutex.synchronize do
        return nil if @drivers.size >= @max_size

        @driver_factory.call.tap { |d| @drivers << d }
      end
    end

    def healthy?(driver)
      driver.title
      true
    rescue StandardError
      false
    end

    def recycle(driver)
      @mutex.synchronize do
        @drivers.delete(driver)
        @driver_factory.call.tap { |d| @drivers << d }
      end
    end

    def checkin(driver)
      return if @shutdown

      @available.push(driver)
    end
  end
end

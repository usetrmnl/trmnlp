require 'optionparser'

options = {
  bind: '127.0.0.1',
  port: 4567
}

# Parse options BEFORE requiring the Sinatra app, since it has its own option-parsing behavior.
# This will remove the option items from ARGV, which is what we want.
OptionParser.new do |opts|
  opts.banner = "Usage: trmnlp serve [directory] [options]"

  opts.on("-b", "--bind [HOST]", "Bind to host address (default: 127.0.0.1)") do |host|
    options[:bind] = host
  end

  opts.on("-p", "--port [PORT]", "Use port (default: 4567)") do |port|
    options[:port] = port
  end
end.parse!

# Must come AFTER parsing options
require_relative '../app'

# Now we can configure things
TRMNLPreview::App.set(:root_dir, ARGV[1] || Dir.pwd)
TRMNLPreview::App.set(:bind, options[:bind])
TRMNLPreview::App.set(:port, options[:port])

# Finally, start the app!
TRMNLPreview::App.run!
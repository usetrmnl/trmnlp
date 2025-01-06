require 'optionparser'

require_relative '../context'

OptionParser.new do |opts|
  opts.banner = "Usage: trmnlp build [directory]"
end.parse!

root = ARGV[1] || Dir.pwd
context = TRMNLPreview::Context.new(root)
context.poll_data

TRMNLPreview::VIEWS.each do |view|
  output_path = File.join(context.temp_dir, "#{view}.html")
  puts "Creating #{output_path}..."
  File.write(output_path, context.render_html(view))
end

puts "Done!"
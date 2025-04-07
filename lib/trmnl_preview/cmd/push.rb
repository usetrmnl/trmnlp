require 'fileutils'
require 'optionparser'
require 'zip'

require_relative '../api_client'
require_relative '../context'

OptionParser.new do |opts|
  opts.banner = "Usage: trmnlp push [id]"
end.parse!

begin
  context = TRMNLPreview::Context.new(Dir.pwd)
rescue StandardError => e
  puts e.message
  exit 1
end

id = ARGV[1] || context.config.plugin.id
if id.nil?
  puts "The plugin ID must be specified in settings.yml, or as an argument."
  exit 1
end

api = TRMNLPreview::APIClient.new(context.config)

Tempfile.create(binmode: true) do |temp_file|
  Zip::File.open(temp_file.path, Zip::File::CREATE) do |zip_file|
    context.paths.src_files.each do |file|
      zip_file.add(File.basename(file), file)
    end
  end

  api.post_plugin_setting_archive(id, temp_file.path)
end


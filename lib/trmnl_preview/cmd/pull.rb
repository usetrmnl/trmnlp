require 'fileutils'
require 'optionparser'
require 'zip'

require_relative '../api_client'
require_relative '../context'

OptionParser.new do |opts|
  opts.banner = "Usage: trmnlp pull [id]"
end.parse!

begin
  context = TRMNLPreview::Context.new(Dir.pwd)
rescue StandardError => e
  puts e.message
  exit 1
end

id = ARGV[1] || context.config.plugin.id
if id.nil?
  puts "The plugin ID must be specified on the first pull."
  exit 1
end

api = TRMNLPreview::APIClient.new(context.config)
temp_path = api.get_plugin_setting_archive(id)

begin
  Zip::File.open(temp_path) do |zip_file|
    zip_file.each do |entry|
      dest_path = context.paths.src_dir.join(entry.name)
      dest_path.dirname.mkpath
      zip_file.extract(entry, dest_path) { true } # overwrite existing
    end
  end
ensure
  temp_path.delete
end

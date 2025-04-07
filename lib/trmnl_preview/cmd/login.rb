paths = TRMNLPreview::Paths.new(Dir.pwd)
app_config = TRMNLPreview::Config::App.new(paths)

puts "Please visit #{app_config.account_uri} to grab your API key, then paste it here."

print "API Key: "
api_key = STDIN.gets.chomp
if api_key.empty?
  puts "API key cannot be empty."
  exit 1
end

app_config.api_key = api_key
app_config.save

puts "Saved changes to #{paths.app_config}"

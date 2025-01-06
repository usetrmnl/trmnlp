class TRMNLPreview::Context
  attr_reader :strategy
  
  def initialize(root)
    config_path = File.join(root, 'config.toml')
    @user_views_dir = File.join(root, 'views')
    @temp_dir = File.join(root, 'tmp')
    @data_json_path = File.join(@temp_dir, 'data.json')

    unless File.exist?(config_path)
      puts "No config.toml found in #{root}"
      exit 1
    end
  
    unless Dir.exist?(@user_views_dir)
      puts "No views found at #{@user_views_dir}"
      exit 1
    end

    config = TomlRB.load_file(config_path)
    @strategy = config['strategy']
    @url = config['url']
    @polling_headers = config['polling_headers'] || {}

    unless ['polling', 'webhook'].include?(@strategy)
      puts "Invalid strategy: #{strategy} (must be 'polling' or 'webhook')"
      exit 1
    end

    FileUtils.mkdir_p(@temp_dir)
  end

  def user_data
    data = JSON.parse(File.read(@data_json_path))
    data = { data: data } if data.is_a?(Array) # per TRMNL docs, bare array is wrapped in 'data' key
    data
  end

  def poll_data
    if @url.nil?
      puts "URL is required for polling strategy"
      exit 1
    end

    print "Fetching #{@url}... "
    payload = URI.open(@url, @polling_headers).read
    File.write(@data_json_path, payload)
    puts "got #{payload.size} bytes"

    user_data
  end

  def set_data(payload)
    File.write(@data_json_path, payload)
  end

  def view_path(view)
    File.join(@user_views_dir, "#{view}.liquid")
  end
end
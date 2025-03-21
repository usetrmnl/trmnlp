module TRMNLPreview
  class Paths
    attr_reader :root, :views_dir, :temp_dir, :data_json, :config

    def initialize(root)
      @root = root
      @views_dir = File.join(root, 'views')
      @temp_dir = File.join(root, 'tmp')
      @data_json = File.join(@temp_dir, 'data.json')
      @config = File.join(root, 'config.toml')
    end
  end
end
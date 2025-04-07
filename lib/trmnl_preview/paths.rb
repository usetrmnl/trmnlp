require 'xdg'

module TRMNLPreview
  class Paths
    attr_reader :root_dir
    
    def initialize(root_dir)
      @root_dir = Pathname.new(root_dir)
      @xdg = XDG.new
    end

    # --- directories ---
    
    def src_dir = root_dir.join('src')

    def build_dir = root_dir.join('_build')
    def create_temp_dir = build_dir.mkpath

    def app_config_dir = xdg.config_home.join('trmnlp')

    def cache_dir = xdg.cache_home.join('trmnl')
    def create_cache_dir = cache_dir.mkpath

    # --- files ---

    def preview_config = root_dir.join('preview.yml')

    def plugin_config = src_dir.join('settings.yml')
      
    def template(view) = src_dir.join("#{view}.liquid")
      
    def app_config = app_config_dir.join('config.yml')

    def user_data = cache_dir.join('data.json')

    def render_template = Pathname.new(__dir__).join('..', '..', 'web', 'views', 'render_html.erb')
    
    def src_files = src_dir.glob('*').select(&:file?)

    # --- utilities ---

    def expand(path) = Pathname.new(path).expand_path(root_dir)

    private

    attr_reader :xdg
  end
end
# frozen_string_literal: true

require 'digest'
require 'xdg'

module TRMNLP
  class Paths
    attr_reader :root_dir

    def initialize(root_dir)
      @root_dir = Pathname.new(root_dir).expand_path
      @xdg = XDG.new
    end

    # --- trmnlp library ---

    def gem_dir = Pathname.new(__dir__).join('..', '..').expand_path

    def templates_dir = gem_dir.join('templates')

    # --- directories ---

    def src_dir = root_dir.join('src')

    def build_dir = root_dir.join('_build')
    def create_build_dir = build_dir.mkpath

    def app_config_dir = xdg.config_home.join('trmnlp')

    def cache_dir = xdg.cache_home.join('trmnl')

    def valid? = trmnlp_config.exist?

    # --- files ---

    def trmnlp_config = root_dir.join('.trmnlp.yml')

    def plugin_config = src_dir.join('settings.yml')

    def template(view) = src_dir.join("#{view}.liquid")

    def shared_template = template('shared')

    def app_config = app_config_dir.join('config.yml')

    # Cached files are keyed per project root so working on two plugins does not
    # clobber a shared file.
    def user_data = cache_dir.join('data', "#{project_key}.json")

    def oauth_tokens = cache_dir.join('oauth', "#{project_key}.json")

    def transform_state = cache_dir.join('state', "#{project_key}.json")
    def fetch_failed_marker = cache_dir.join('state', "#{project_key}.fetch_failed")

    def transform_output = cache_dir.join('transform_output', "#{project_key}.json")

    def render_template = Pathname.new(__dir__).join('..', '..', 'web', 'views', 'render_html.erb')

    def src_files = src_dir.glob('*').select(&:file?)

    # File extension → transform language identifier.
    TRANSFORM_EXTENSIONS = {
      '.py' => 'python',
      '.rb' => 'ruby',
      '.php' => 'php',
      '.js' => 'node'
    }.freeze

    # Locate src/transform.{py,rb,php,js}. Returns [Pathname, language]
    # or [nil, nil] if no transform file exists.
    def transform_file
      TRANSFORM_EXTENSIONS.each do |ext, language|
        candidate = src_dir.join("transform#{ext}")
        return [candidate, language] if candidate.exist?
      end
      [nil, nil]
    end

    # --- utilities ---

    def expand(path) = Pathname.new(path).expand_path(root_dir)

    private

    attr_reader :xdg

    def project_key = Digest::SHA256.hexdigest(root_dir.to_s)[0, 16]
  end
end

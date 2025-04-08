require 'faraday'
require 'faraday/multipart'

require_relative 'config'

module TRMNLPreview
  class APIClient
    def initialize(config)
      @config = config
    end

    def get_plugin_setting_archive(id)
      response = conn.get("plugin_settings/#{id}/archive")

      if response.status == 200
        temp_file = Tempfile.new(["plugin_settings_#{id}", '.zip'])
        temp_file.binmode
        temp_file.write(response.body)
        temp_file.rewind

        # return the path to the temp file
        Pathname.new(temp_file.path)
      else
        raise "Failed to download plugin settings archive: #{response.status} #{response.body}"
      end
    end

    def post_plugin_setting_archive(id, path)
      payload = {
        file: Faraday::Multipart::FilePart.new(path, 'application/zip')
      }

      response = conn.post("plugin_settings/#{id}/archive", payload)

      if response.status == 200
        true
      else
        raise "Failed to upload plugin settings archive: #{response.status} #{response.body}"
      end
    end

    private
  
    attr_reader :config
  
    def api_uri = config.app.api_uri

    def conn
      @conn ||= Faraday.new(url: api_uri, headers:) do |f|
        f.request :multipart
      end
    end


    def headers
      {
        'Authorization' => "Bearer #{config.app.api_key}",
        'User-Agent' => "trmnlp/#{VERSION}",
      }
    end
  end
end
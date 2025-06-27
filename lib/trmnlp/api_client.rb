require 'faraday'
require 'faraday/multipart'

require_relative 'config'

module TRMNLP
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

        # return the temp file IO
        temp_file
      else
        raise Error, "failed to download plugin settings archive: #{response.status} #{response.body}"
      end
    end

    def post_plugin_setting_archive(id, path)
      filepart = Faraday::Multipart::FilePart.new(path, 'application/zip')

      payload = {
        file: filepart
      }

      response = conn.post("plugin_settings/#{id}/archive", payload)

      filepart.close

      if response.status == 200
        JSON.parse(response.body)
      else
        raise Error, "failed to upload plugin settings archive: #{response.status} #{response.body}"
      end
    end

    def post_plugin_setting(params)
      response = conn.post("plugin_settings", params.to_json, content_type: 'application/json')

      if response.status == 200
        JSON.parse(response.body)
      else
        raise Error, "failed to create plugin setting: #{response.status} #{response.body}"
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
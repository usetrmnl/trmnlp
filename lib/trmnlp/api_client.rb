# frozen_string_literal: true

require 'faraday'
require 'faraday/multipart'

require_relative 'config'

module TRMNLP
  class APIClient
    def initialize(config)
      @config = config
    end

    def get_me
      response = conn.get('me')

      raise Error, "failed to fetch user info: #{response.status} #{response.body}" unless response.status == 200

      JSON.parse(response.body)['data']
    end

    def get_plugin_settings
      response = conn.get('plugin_settings')

      raise Error, "failed to list plugin settings: #{response.status} #{response.body}" unless response.status == 200

      JSON.parse(response.body)['data']
    end

    def get_plugin_setting_archive(id)
      response = conn.get("plugin_settings/#{id}/archive")

      unless response.status == 200
        raise Error, "failed to download plugin settings archive: #{response.status} #{response.body}"
      end

      temp_file = Tempfile.new(["plugin_settings_#{id}", '.zip'])
      temp_file.binmode
      temp_file.write(response.body)
      temp_file.rewind

      # return the temp file IO
      temp_file
    end

    def post_plugin_setting_archive(id, path)
      filepart = Faraday::Multipart::FilePart.new(path, 'application/zip')

      payload = {
        file: filepart
      }

      response = conn.post("plugin_settings/#{id}/archive", payload)

      filepart.close

      unless response.status == 200
        raise Error, "failed to upload plugin settings archive: #{response.status} #{response.body}"
      end

      JSON.parse(response.body)
    end

    def post_plugin_setting(params)
      response = conn.post('plugin_settings', params.to_json, content_type: 'application/json')

      raise Error, "failed to create plugin setting: #{response.status} #{response.body}" unless response.status == 200

      JSON.parse(response.body)
    end

    def delete_plugin_setting(id)
      response = conn.delete("plugin_settings/#{id}")

      raise Error, "failed to delete plugin setting: #{response.status} #{response.body}" unless response.status == 204

      true
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
        'User-Agent' => "trmnlp/#{VERSION}"
      }
    end
  end
end

# frozen_string_literal: true

require 'active_support'
require 'active_support/time'
require 'json'

module TRMNLP
  class UserDataAssembler
    DEFAULT_DEVICE_WIDTH = 800
    DEFAULT_DEVICE_HEIGHT = 480

    def initialize(config:, paths:, transform_pipeline:)
      @config = config
      @paths = paths
      @transform_pipeline = transform_pipeline
    end

    # Assembles the merged data hash. The trmnl namespace is built first,
    # layered with static_data / cached polled data / user_data_overrides,
    # then piped through the transform. The assembled trmnl namespace
    # (overrides included) is re-applied after the transform so it
    # survives even when the transform doesn't pass it through.
    def call(device: {})
      namespace = base_trmnl_data(device:)
      merged = assemble(namespace)
      result = transform_pipeline.call(transform_input(merged))
      result['trmnl'] = merged['trmnl']
      result
    end

    def device_from_params(params)
      { 'width' => params[:width]&.to_i, 'height' => params[:height]&.to_i }.compact
    end

    private

    attr_reader :config, :paths, :transform_pipeline

    def assemble(namespace)
      data = namespace.dup
      merge_source_data!(data)
      data.deep_merge!(config.project.user_data_overrides)
      data
    end

    # The hosted service exposes only user/device/plugin_settings to the
    # transform; the system namespace is added afterward. Mirror that slice
    # so transforms behave the same locally as in production.
    def transform_input(merged)
      merged.merge('trmnl' => merged['trmnl'].slice('user', 'device', 'plugin_settings'))
    end

    def merge_source_data!(data)
      if config.plugin.static?
        data.merge!(config.plugin.static_data)
      elsif paths.user_data.exist?
        data.merge!(JSON.parse(paths.user_data.read))
      end
    end

    def base_trmnl_data(device:)
      { 'trmnl' => trmnl_namespace(device:) }
    end

    def trmnl_namespace(device:)
      {
        'user' => user_namespace,
        'device' => device_namespace(device),
        'system' => { 'timestamp_utc' => Time.now.utc.to_i },
        'plugin_settings' => plugin_settings_namespace
      }
    end

    def user_namespace
      tz = ActiveSupport::TimeZone.find_tzinfo(config.project.time_zone)
      iana = tz.name
      {
        'id' => 1,
        'name' => 'name', 'first_name' => 'first_name', 'last_name' => 'last_name',
        'locale' => 'en', 'time_zone' => ActiveSupport::TimeZone::MAPPING.invert[iana] || iana,
        'time_zone_iana' => iana, 'utc_offset' => tz.utc_offset
      }
    end

    def device_namespace(device)
      {
        'friendly_id' => 'ABC123', 'percent_charged' => 85.0, 'wifi_strength' => 90,
        'height' => device['height'] || DEFAULT_DEVICE_HEIGHT,
        'width' => device['width'] || DEFAULT_DEVICE_WIDTH
      }
    end

    def plugin_settings_namespace
      {
        'instance_name' => 'instance_name',
        'strategy' => config.plugin.strategy,
        'dark_mode' => config.plugin.dark_mode,
        'polling_headers' => config.plugin.polling_headers_encoded,
        'polling_url' => config.plugin.polling_url_text,
        'custom_fields_values' => config.project.custom_fields
      }
    end
  end
end

# frozen_string_literal: true

require 'active_support'
require 'active_support/time'
require 'json'

require_relative 'transform_state'

module TRMNLP
  class UserDataAssembler
    DEFAULT_DEVICE_WIDTH = 800
    DEFAULT_DEVICE_HEIGHT = 480

    def initialize(config:, paths:, transform_pipeline:)
      @config = config
      @paths = paths
      @transform_pipeline = transform_pipeline
      @transform_state = TransformState.new(paths:)
    end

    # Assembles the merged data hash. The trmnl namespace is built first,
    # layered with static_data / cached polled data / user_data_overrides,
    # then piped through the transform. The assembled trmnl namespace
    # (overrides included) is re-applied after the transform so it
    # survives even when the transform doesn't pass it through.
    def call(device: {})
      merged = assemble(base_trmnl_data(device:), source_data)
      # TRMNL transforms a webhook post once, as it arrives, so a render shows the stored result.
      result = config.plugin.webhook? ? merged.except('trmnl') : transform_pipeline.call(transform_input(merged))
      # The markup renders the state this run's transform kept, as on TRMNL.
      result['trmnl'] = merged['trmnl'].merge('state' => transform_state.read)
      result
    end

    def transform_webhook_post(merge_variables)
      transform_pipeline.call(transform_input(assemble(base_trmnl_data(device: {}), merge_variables)))
    end

    def device_from_params(params)
      { 'width' => params[:width]&.to_i, 'height' => params[:height]&.to_i, 'model' => params[:model],
        'bit_depth' => params[:bit_depth]&.to_i, 'orientation' => params[:orientation] }.compact
    end

    private

    attr_reader :config, :paths, :transform_pipeline, :transform_state

    # The trmnl namespace wins over a trmnl key in the fetched data, as on TRMNL; only .trmnlp.yml overrides it.
    def assemble(namespace, source)
      source.merge(namespace).deep_merge(config.project.user_data_overrides)
    end

    # The hosted service exposes only user/device/plugin_settings/state to the
    # transform; the system namespace is added afterward. Mirror that slice
    # so transforms behave the same locally as in production.
    def transform_input(merged)
      trmnl = merged['trmnl'].slice('user', 'device', 'plugin_settings', 'state')
      merged.merge('trmnl' => trmnl.merge('previous_merge_variables' => previous_merge_variables))
    end

    # What the last run stored for the markup: a webhook's stored data, otherwise the last transform output.
    def previous_merge_variables = config.plugin.webhook? ? source_data : transform_pipeline.previous_output

    def source_data
      if config.plugin.static?
        config.plugin.static_data
      elsif paths.user_data.exist?
        JSON.parse(paths.user_data.read)
      else
        {}
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
        'plugin_settings' => plugin_settings_namespace,
        'state' => transform_state.read
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
        'width' => device['width'] || DEFAULT_DEVICE_WIDTH,
        'model' => device['model'] || 'og_plus', 'bit_depth' => device['bit_depth'] || 2,
        'orientation' => device['orientation'] || 'landscape',
        'firmware_version' => '1.8.17', 'refresh_interval_seconds' => 900,
        'sleep_mode_enabled' => false, 'sleep_start_time' => 1320, 'sleep_end_time' => 480
      }
    end

    def plugin_settings_namespace
      {
        'instance_name' => config.plugin.settings['name'],
        'refresh_interval_minutes' => config.plugin.refresh_interval,
        'strategy' => config.plugin.strategy,
        'dark_mode' => config.plugin.dark_mode,
        'no_screen_padding' => config.plugin.no_screen_padding,
        'custom_fields_values' => config.project.custom_fields
      }.merge(polling_url_setting, data_fetched_setting)
    end

    # The polling url can carry the author's API key, so TRMNL exposes it only to a polling plugin.
    def polling_url_setting = config.plugin.polling? ? { 'polling_url' => config.plugin.polling_url_text } : {}

    def data_fetched_setting
      fetched = !config.plugin.static? && paths.user_data.exist?
      fetched ? { 'data_fetched_utc' => paths.user_data.mtime.to_i } : {}
    end
  end
end

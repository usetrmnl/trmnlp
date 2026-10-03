# frozen_string_literal: true

module TRMNLP
  # A plugin_merge plugin's data as TRMNL builds it: each referenced plugin's locals under "<keyname>_<id>".
  # Locally each reference names another trmnlp project, listed under merged_plugins in .trmnlp.yml.
  class MergedPluginLocals
    SENSITIVE_KEYNAMES = %w[polling_headers headers polling_body oauth_token_headers oauth_token_params].freeze

    def initialize(config:, paths:)
      @config = config
      @paths = paths
    end

    def call
      # A project met again is a cycle and merges as empty.
      root_dirs_being_merged = (Thread.current[:trmnlp_merged_plugin_dirs] ||= [])
      return {} if root_dirs_being_merged.include?(paths.root_dir)

      root_dirs_being_merged.push(paths.root_dir)
      begin
        merged_locals
      ensure
        root_dirs_being_merged.pop
      end
    end

    private

    attr_reader :config, :paths

    def merged_locals
      locals = config.project.merged_plugins.to_h { |reference, dir| [reference, plugin_locals(paths.expand(dir))] }
      instance_selections.each { |keyname, selected| locals[keyname] = locals[selected] if locals.key?(selected) }
      locals
    end

    def plugin_locals(dir)
      context = Context.new(dir)
      context.validate!
      locals = { 'merge_variables' => context.user_data_assembler.call.except('trmnl') }
      values = shareable_custom_fields_values(context.config.plugin)
      values.empty? ? locals : locals.merge('custom_fields_values' => values)
    end

    def shareable_custom_fields_values(plugin)
      secret = plugin.custom_field_definitions.select do |field|
        field['field_type'] == 'password' || SENSITIVE_KEYNAMES.include?(field['keyname'])
      end
      plugin.custom_fields_values.except(*secret.map { it['keyname'] })
    end

    def instance_selections
      fields = config.plugin.custom_field_definitions.select { it['field_type'] == 'plugin_instance_select' }
      config.plugin.custom_fields_values.slice(*fields.map { it['keyname'] }).reject { |_, selected| selected.empty? }
    end
  end
end

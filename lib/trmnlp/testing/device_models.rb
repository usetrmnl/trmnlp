# frozen_string_literal: true

require 'faraday'
require 'json'

require_relative '../errors'

module TRMNLP
  module Testing
    # TRMNL's device models, as `trmnlp serve`'s picker loads them, turned into what a render needs.
    module DeviceModels
      API_URL = 'https://trmnl.com/api'

      Device = Data.define(:name, :width, :height, :bit_depth, :screen_classes, :image_size_limit) do
        def render_params = { width:, height:, model: name, bit_depth: }
      end

      module_function

      def names = models.map { it['name'] }

      # A model name, or a Hash of width:, height:, bit_depth: and optionally screen_classes: for a custom screen.
      def find(device, orientation: :landscape, palette: nil)
        return custom(device) if device.is_a?(Hash)

        model = models.find { it['name'] == device.to_s } ||
                raise(TestingError, "Unknown device #{device.inspect}; known: #{names.join(', ')}")
        portrait = orientation.to_s == 'portrait'
        width, height = portrait ? model.values_at('height', 'width') : model.values_at('width', 'height')
        chosen = palette_for(model, palette)
        Device.new(name: model['name'], width:, height:, bit_depth: bit_depth(model, chosen),
                   screen_classes: screen_classes(model, chosen, portrait), image_size_limit: model['image_size_limit'])
      end

      # The picker's classes: palette, device, size, then portrait.
      def screen_classes(model, palette, portrait)
        css = model.dig('css', 'classes') || {}
        ['screen', palette&.fetch('framework_class'), css['device'], css['size'],
         ('screen--portrait' if portrait)].compact.join(' ')
      end

      def palette_for(model, id)
        candidates = palettes.select { model['palette_ids'].to_a.include?(it['id']) }
        return candidates.find { it['id'] == id.to_s } || raise(TestingError, unknown_palette(model, id)) if id

        candidates.find { it['grays'] == 2**model['bit_depth'] } || candidates.first
      end

      # A palette of fewer grays draws the PNG at that depth, as the device then does.
      def bit_depth(model, palette)
        grays = palette && palette['grays']
        grays ? [Math.log2(grays).ceil, model['bit_depth']].min : model['bit_depth']
      end

      def unknown_palette(model, id)
        "Model #{model['name']} has no palette #{id.inspect}; it has #{model['palette_ids'].to_a.join(', ')}"
      end

      def custom(device)
        device = device.transform_keys(&:to_sym)
        Device.new(name: device.fetch(:model, 'custom'), width: device.fetch(:width), height: device.fetch(:height),
                   bit_depth: device.fetch(:bit_depth, 1), screen_classes: device[:screen_classes],
                   image_size_limit: device[:image_size_limit])
      end

      def models = @models ||= fetch('models')
      def palettes = @palettes ||= fetch('palettes')

      def fetch(resource)
        response = Faraday.get("#{API_URL}/#{resource}")
        raise TestingError, "Could not load TRMNL's #{resource} (HTTP #{response.status})" unless response.success?

        body = JSON.parse(response.body)
        body.is_a?(Hash) ? body.fetch('data') : body
      rescue Faraday::Error => e
        raise TestingError, "Could not load TRMNL's #{resource}: #{e.message}. Pass a device Hash to test offline."
      end
    end
  end
end

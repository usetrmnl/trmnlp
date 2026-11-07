# frozen_string_literal: true

require 'erb'

module TRMNLP
  # Form-encodes nested values as TRMNL's HTTP client (HTTParty) does, so a third-party plugin gets the same body.
  module FormBody
    def self.encode(values)
      values.flat_map { |key, value| pairs(key.to_s, value) }
            .map { |name, value| "#{ERB::Util.url_encode(name)}=#{ERB::Util.url_encode(value.to_s)}" }.join('&')
    end

    def self.pairs(name, value)
      return nested_pairs(name, value) if value.is_a?(Hash)
      return [[name, value]] unless value.is_a?(Array)

      value.empty? ? [["#{name}[]", '']] : value.flat_map { pairs("#{name}[]", it) }
    end

    # Breadth first: a hash's own values come before those of the hashes inside it, and an empty list sends nothing.
    def self.nested_pairs(name, hash)
      queue = [[name, hash]]
      queue.each_with_object([]) do |(parent, children), found|
        children.each do |key, child|
          child_name = "#{parent}[#{key}]"
          next queue << [child_name, child] if child.is_a?(Hash)

          found.concat(child.is_a?(Array) ? child.flat_map { pairs("#{child_name}[]", it) } : [[child_name, child]])
        end
      end
    end
  end
end

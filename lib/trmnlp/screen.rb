# frozen_string_literal: true

module TRMNLP
  class Screen < Data.define(:name, :mashup_classes)
    FULL             = new(name: 'full',             mashup_classes: nil)
    HALF_HORIZONTAL  = new(name: 'half_horizontal',  mashup_classes: 'mashup mashup--1Tx1B')
    HALF_VERTICAL    = new(name: 'half_vertical',    mashup_classes: 'mashup mashup--1Lx1R')
    QUADRANT         = new(name: 'quadrant',         mashup_classes: 'mashup mashup--2x2')

    ALL = [FULL, HALF_HORIZONTAL, HALF_VERTICAL, QUADRANT].freeze

    def self.all = ALL
    def self.find(name) = ALL.find { it.name == name }
    def self.names = ALL.map(&:name)
  end
end

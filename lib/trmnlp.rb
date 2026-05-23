# frozen_string_literal: true

module TRMNLP; end
require 'oj'
require 'trmnl/liquid'
Oj.mimic_JSON
TRMNL::Liquid::RailsHelpers = Module.new unless defined?(TRMNL::Liquid::RailsHelpers)
require_relative 'trmnlp/errors'
require_relative 'trmnlp/config'
require_relative 'trmnlp/context'
require_relative 'trmnlp/screen'
require_relative 'trmnlp/version'

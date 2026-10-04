# frozen_string_literal: true

module TRMNLP; end
require 'oj'
require 'trmnl/liquid'
require_relative 'trmnlp/qr_code_intrinsic_size'
Oj.mimic_JSON
require_relative 'trmnlp/rails_helpers'
require_relative 'trmnlp/errors'
require_relative 'trmnlp/oauth'
require_relative 'trmnlp/config'
require_relative 'trmnlp/context'
require_relative 'trmnlp/screen'
require_relative 'trmnlp/version'

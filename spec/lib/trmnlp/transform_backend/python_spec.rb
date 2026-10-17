# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/transform_backend/python'

RSpec.describe TRMNLP::TransformBackend::Python do
  describe '.interpreter' do
    it 'keeps a Python it cannot make a virtual environment from' do
      Dir.mktmpdir do |dir|
        expect(described_class.interpreter('/missing/python3', venv_dir: Pathname(dir).join('python')))
          .to eq('/missing/python3')
      end
    end
  end
end

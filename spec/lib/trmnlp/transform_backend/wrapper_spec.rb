# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/transform_backend/wrapper'

RSpec.describe TRMNLP::TransformBackend::Wrapper do
  describe '.for' do
    it 'returns nil for an unknown language' do
      expect(described_class.for('cobol', 'x', 'y')).to be_nil
    end

    it 'wraps user and sink code for every supported language' do
      wrapped = %w[python ruby node php].map { |lang| described_class.for(lang, 'USER_CODE', 'SINK_CODE') }

      expect(wrapped).to all(include('USER_CODE').and(include('SINK_CODE')))
    end
  end

  describe '.node' do
    it 'includes both run() and transform() dispatch (production parity)' do
      wrapped = described_class.node('// noop', 'sink();')
      expect(wrapped).to include('typeof run === "function"')
      expect(wrapped).to include('typeof transform === "function"')
      expect(wrapped).to include('typeof result !== "undefined"')
    end
  end

  describe '.php' do
    it 'strips a leading <?php tag from user code' do
      wrapped = described_class.php("<?php\nfunction run($i) { return []; }", 'sink();')
      # Should appear once (the wrapper's own opening tag), not twice
      expect(wrapped.scan('<?php').size).to eq(1)
    end
  end
end

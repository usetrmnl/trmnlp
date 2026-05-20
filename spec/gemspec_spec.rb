# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'trmnl_preview.gemspec' do
  subject(:gemspec) { Gem::Specification.load(gemspec_path) }

  let(:gemspec_path) { File.expand_path('../trmnl_preview.gemspec', __dir__) }

  # The .github/ template directory is hidden; a plain Dir[] glob skips it and
  # would silently drop the scaffolded workflow from the published gem.
  it 'packages the GitHub Actions workflow template' do
    expect(gemspec.files).to include('templates/init/.github/workflows/trmnl.yml')
  end
end

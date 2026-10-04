# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/testing/node_version'

RSpec.describe TRMNLP::Testing::NodeVersion do
  before { described_class.checked.clear }

  def node_answering(version)
    allow(Open3).to receive(:capture2).with('/bin/node', '--version').and_return(["#{version}\n", nil])
  end

  it 'reads the version of a real Node' do
    expect { described_class.check!(RbConfig.ruby) }.to raise_error(TRMNLP::TestingError, /is ruby/)
  end

  it 'lets Node 24 through, which sends fetch through the mock proxy' do
    node_answering('v24.9.0')

    expect { described_class.check!('/bin/node') }.not_to raise_error
  end

  it 'refuses an older Node, whose fetch would skip the mocks and reach the real network' do
    node_answering('v20.19.2')

    expect { described_class.check!('/bin/node') }.to raise_error(TRMNLP::TestingError, /Node 24 or newer.*v20\.19\.2/)
  end
end

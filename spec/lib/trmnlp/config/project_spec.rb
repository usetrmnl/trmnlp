require 'spec_helper'

RSpec.describe TRMNLP::Config::Project do
  let(:root_dir) { File.join(__dir__, '../../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(root_dir) }
  subject { TRMNLP::Config::Project.new(paths) }

  describe '#custom_fields' do
    context 'when there is a .trmnlp yaml file in the path' do
      it 'transforms all values to strings' do
        expect(subject.custom_fields).to include('character_name' => 'Bluey')
        expect(subject.custom_fields).to include('character_age' => '7')
      end
    end

    context 'when there is no .trmnlp yaml file in the path' do
      let(:root_dir) { 'not-a-valid-path' }
      it 'returns an empty hash' do
        expect(subject.custom_fields).to eq({})
      end
    end
  end
end

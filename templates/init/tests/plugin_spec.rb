# frozen_string_literal: true

# This plugin's tests, run with `trmnlp test` (add `--report report` for a page of every screen it drew).
# Docs: https://github.com/usetrmnl/trmnlp#testing-plugins
RSpec.describe 'My Plugin' do
  # Canned answers for the requests the plugin makes, its polling urls and its transform's own, e.g.
  #   { 'https://api.example.com/*' => { json: { temperature: 21 } } }
  let(:mocks) { {} }

  # The values of the custom fields in src/settings.yml to test with.
  let(:custom_fields) { {} }

  %w[full half_horizontal half_vertical quadrant].each do |view|
    it "draws the #{view} view without overflow or page errors" do
      screen = trmnl.render(view:, mocks:, custom_fields:)

      expect(screen).to have_no_overflow
      expect(screen).to have_no_problems
    end
  end

  it "stays within TRMNL's serverless limits" do
    expect(trmnl.transform(mocks:, custom_fields:)).to stay_within_serverless_limits
  end

  # A picture of the full view, compared pixel for pixel on every run. Record it once with
  # `trmnlp test --update` (or the workflow's update_snapshots run) and commit tests/snapshots.
  #
  # it 'looks as it did' do
  #   expect(trmnl.render(mocks:, custom_fields:)).to match_snapshot
  # end
end

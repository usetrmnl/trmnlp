# frozen_string_literal: true

# This plugin's tests, run with `trmnlp test` (add `--report report` for a page of every screen it drew).
# Docs: https://github.com/usetrmnl/trmnlp#testing-plugins
RSpec.describe 'My Plugin' do
  # Canned answers for the requests the plugin makes, its polling urls and its transform's own, e.g.
  #   { 'https://api.example.com/*' => { json: { temperature: 21 } } }
  let(:mocks) { {} }

  # The values of the custom fields in src/settings.yml to test with.
  let(:custom_fields) { {} }

  # Every view on TRMNL's devices, a failing API and every select option, checked for page errors and leaked values.
  it_behaves_like 'a publishable recipe'

  # A picture of the full view, compared pixel for pixel on every run. Record it once with
  # `trmnlp test --update` (or the workflow's update_snapshots run) and commit tests/snapshots.
  #
  # it 'looks as it did' do
  #   expect(trmnl.render(mocks:, custom_fields:)).to match_snapshot
  # end
end

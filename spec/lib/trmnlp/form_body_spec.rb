# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::FormBody do
  it 'encodes nested values exactly as TRMNL posts them to a third-party plugin' do
    variables = { 'user_uuid' => 'u-1',
                  'trmnl' => { 'user' => { 'name' => 'Ana Lí', 'id' => 1 },
                               'device' => { 'firmware_version' => nil, 'sleep_mode_enabled' => false },
                               'state' => {},
                               'plugin_settings' => { 'custom_fields_values' => { 'tags' => %w[x y], 'none' => [] },
                                                      'instance_name' => 'A & B' } } }

    expect(described_class.encode(variables)).to eq(
      'user_uuid=u-1&trmnl%5Buser%5D%5Bname%5D=Ana%20L%C3%AD&trmnl%5Buser%5D%5Bid%5D=1' \
      '&trmnl%5Bdevice%5D%5Bfirmware_version%5D=&trmnl%5Bdevice%5D%5Bsleep_mode_enabled%5D=false' \
      '&trmnl%5Bplugin_settings%5D%5Binstance_name%5D=A%20%26%20B' \
      '&trmnl%5Bplugin_settings%5D%5Bcustom_fields_values%5D%5Btags%5D%5B%5D=x' \
      '&trmnl%5Bplugin_settings%5D%5Bcustom_fields_values%5D%5Btags%5D%5B%5D=y'
    )
  end

  it 'sends an empty top-level list as one empty value' do
    expect(described_class.encode('ids' => [])).to eq('ids%5B%5D=')
  end
end

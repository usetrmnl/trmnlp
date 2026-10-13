# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/testing/ink_count'
require 'trmnlp/testing/screen'

RSpec.describe TRMNLP::Testing::InkCount do
  let(:dir) { Dir.mktmpdir('trmnlp-ink-') }

  after { FileUtils.remove_entry(dir) }

  # A 100 by 100 picture in one color with a 10 by 10 square in another.
  def picture(background, square)
    File.join(dir, "#{background}-#{square}.png").tap do |path|
      MiniMagick.convert do |convert|
        convert << '-size' << '100x100' << "xc:#{background}" << '-fill' << square
        convert << '-draw' << 'rectangle 0,0 9,9' << path
      end
    end
  end

  it 'counts the pixels that stand out from a white background' do
    expect(described_class.new(picture('white', 'black')).pixels).to eq(100)
  end

  it 'counts the pixels that stand out from a black background' do
    expect(described_class.new(picture('black', 'white')).pixels).to eq(100)
  end

  it 'counts only inside the area asked for' do
    area = TRMNLP::Testing::Screen::Box.new(left: 5, top: 5, right: 55, bottom: 55, width: 50, height: 50)

    expect(described_class.new(picture('white', 'black'), area:).pixels).to eq(25)
  end

  it 'leaves out a shade close to the background' do
    expect(described_class.new(picture('white', 'gray60')).pixels).to eq(0)
  end
end

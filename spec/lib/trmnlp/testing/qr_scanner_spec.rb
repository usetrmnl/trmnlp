# frozen_string_literal: true

require 'spec_helper'
require 'rqrcode'
require 'tmpdir'
require 'trmnlp/testing/qr_scanner'
require 'trmnlp/testing/screen'

RSpec.describe TRMNLP::Testing::QrScanner do
  let(:dir) { Dir.mktmpdir('trmnlp-qr-') }

  after { FileUtils.remove_entry(dir) }

  # A white picture with one code per text, side by side, 4 pixels per module.
  def picture(*texts)
    codes = texts.map do |text|
      path = File.join(dir, "#{text.hash.abs}.png")
      RQRCode::QRCode.new(text).as_png(module_px_size: 4, border_modules: 4).save(path)
      path
    end
    File.join(dir, 'picture.png').tap do |path|
      MiniMagick::Tool.new('convert') { |convert| convert.merge!(codes) << '+append' << path }
    end
  end

  it 'reads the text of a code' do
    expect(described_class.new(picture('https://trmnl.com/pay?id=1')).texts).to eq(['https://trmnl.com/pay?id=1'])
  end

  it 'reads every code in the picture' do
    expect(described_class.new(picture('first', 'second')).texts).to contain_exactly('first', 'second')
  end

  it 'reads only the area asked for' do
    area = TRMNLP::Testing::Screen::Box.new(left: 0, top: 0, right: 116, bottom: 116, width: 116, height: 116)

    expect(described_class.new(picture('first', 'second'), area:).texts).to eq(['first'])
  end

  it 'reads only the visible part of an area that starts off the picture' do
    area = TRMNLP::Testing::Screen::Box.new(left: -116, top: 0, right: 116, bottom: 116, width: 232, height: 116)

    expect(described_class.new(picture('first', 'second'), area:).texts).to eq(['first'])
  end

  it 'finds nothing in an area wholly off the picture' do
    area = TRMNLP::Testing::Screen::Box.new(left: -116, top: 0, right: 0, bottom: 116, width: 116, height: 116)

    expect(described_class.new(picture('first', 'second'), area:).texts).to eq([])
  end

  it 'finds nothing in a picture without a code' do
    blank = File.join(dir, 'blank.png')
    MiniMagick::Tool.new('convert') { |convert| convert << '-size' << '100x100' << 'xc:white' << blank }

    expect(described_class.new(blank).texts).to eq([])
  end

  it 'raises with the error from zbar when it cannot read the picture' do
    unreadable = File.join(dir, 'unreadable.png').tap { File.write(it, 'not a png') }

    expect { described_class.new(unreadable).texts }.to raise_error(TRMNLP::TestingError, /improper image header/)
  end

  it 'says what to install when zbar is missing' do
    stub_const("#{described_class}::COMMAND", 'zbarimg-that-is-not-installed')

    expect { described_class.new(picture('text')).texts }.to raise_error(TRMNLP::TestingError, /zbar-tools/)
  end
end

# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/screen_generator'
require 'open3'
require 'tmpdir'

# rubocop:disable Lint/ConstantDefinitionInBlock

# Every palette of TRMNL's /api/palettes (Framework 3.4 "Color Palettes") through ScreenGenerator and the real
# ImageMagick. Limited-ink palettes dither framework colors in the CSS, so the image step only has to hold the inks.
RSpec.describe TRMNLP::ScreenGenerator, 'for every TRMNL palette' do
  def self.palette(id, grays, framework_class, colors = nil)
    { 'id' => id, 'grays' => grays, 'framework_class' => framework_class, 'colors' => colors }.compact
  end

  PALETTES = [
    palette('bw', 2, 'screen--1bit'), palette('gray-4', 4, 'screen--2bit'),
    palette('gray-16', 16, 'screen--4bit'), palette('gray-256', 256, 'screen--4bit'),
    palette('color-3bwr', 2, 'screen--color-3bwr', %w[#000000 #FF0000 #FFFFFF]),
    palette('color-3bwy', 2, 'screen--color-3bwy', %w[#000000 #FFFF00 #FFFFFF]),
    palette('color-4bwry', 2, 'screen--color-4bwry', %w[#000000 #FF0000 #FFFFFF #FFFF00]),
    palette('color-6a', 2, 'screen--color-6a', %w[#FF0000 #00FF00 #0000FF #FFFF00 #000000 #FFFFFF]),
    palette('color-7a', 2, 'screen--color-7a', %w[#000000 #FFFFFF #FF0000 #00FF00 #0000FF #FFFF00 #FFA500]),
    palette('color-12bit', 2, 'screen--color-full'), palette('color-24bit', 2, 'screen--color-full')
  ].freeze

  let(:dir) { Dir.mktmpdir }
  let(:source) { File.join(dir, 'source.png') }
  let(:shot) { File.join(dir, 'shot.png') }
  let(:tempfile) { instance_double(Tempfile, path: shot) }
  let(:screenshot) { instance_double(TRMNLP::Screenshot, call: tempfile) }

  before do
    allow(TRMNLP::Testing::DeviceModels).to receive(:palettes).and_return(PALETTES)
    # 256 grays, a red-to-blue ramp and a green block: a color pixel the palette may or may not hold.
    run('magick', '(', '-size', '64x256', 'gradient:black-white', ')', '(', '-size', '64x256', 'gradient:red-blue', ')',
        '(', '-size', '64x256', 'xc:#33AA55', ')', '+append', source)
    FileUtils.cp(source, shot)
  end

  after { FileUtils.remove_entry(dir) }

  def run(*cmd)
    out, err, status = Open3.capture3(*cmd)
    raise err unless status.success?

    out
  end

  def colors(file) = run('magick', file, '-unique-colors', '-depth', '8', 'txt:-').scan(/#[0-9A-F]{6}/).uniq.sort

  def render(entry, html_extra = '')
    html = %(<div class="screen #{entry['framework_class']}#{html_extra}">x</div>)
    described_class.new(html, screenshot:, width: 192, height: 256, palette_id: entry['id']).process
    colors(shot)
  end

  def self.gray?(hex) = hex[1, 2] == hex[3, 2] && hex[3, 2] == hex[5, 2]
  def gray?(hex) = self.class.gray?(hex)

  def self.channels(out) = out.flat_map { [it[1, 2], it[3, 2], it[5, 2]] }.uniq

  def identical?
    _out, _err, status = Open3.capture3('magick', 'compare', '-metric', 'AE', source, shot, 'null:')
    status.success?
  end

  # id => [what the output must hold, whether a color (non-gray) pixel must survive]
  CHECKS = {
    'bw' => [->(out, _) { out.size == 2 && out.all? { gray?(it) } }, false],
    'gray-4' => [->(out, _) { out.size == 4 && out.all? { gray?(it) } }, false],
    'gray-16' => [->(out, _) { out.size == 16 && out.all? { gray?(it) } }, false],
    'gray-256' => [->(out, _) { out.size > 16 && out.all? { gray?(it) } }, false],
    'color-12bit' => [->(out, _) { channels(out).size <= 16 }, true],
    'color-24bit' => [->(_, spec) { spec.send(:identical?) }, true]
  }.freeze

  PALETTES.each do |entry|
    context entry['id'] do
      let(:out) { render(entry) }

      it 'holds only what the palette can show' do
        check, = CHECKS[entry['id']]
        ok = check ? check.call(out, self) : (out - entry['colors']).empty?
        expect(ok).to be(true), "unexpected output colors: #{out.first(20)}"
      end

      it 'keeps color exactly where the palette has color' do
        _, keeps = CHECKS[entry['id']]
        keeps = !(entry.fetch('colors', []) - %w[#000000 #FFFFFF]).empty? if keeps.nil?
        expect(out.any? { !gray?(it) }).to be(keeps)
      end
    end
  end
end
# rubocop:enable Lint/ConstantDefinitionInBlock

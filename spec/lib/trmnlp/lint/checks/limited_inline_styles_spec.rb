# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/limited_inline_styles'

RSpec.describe TRMNLP::Lint::Checks::LimitedInlineStyles do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, all_markup: markup) }

  describe '#issues' do
    context 'when the markup leans on more inline style properties than allowed' do
      let(:markup) do
        '<div style="padding:1px;margin:1px;font-size:1px;text-align:left;' \
          'background-color:red;border-radius:1px;object-fit:cover">busy</div>'
      end

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when the markup uses few inline style properties' do
      let(:markup) { '<div style="padding: 1em">tidy</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with six declarations of properties outside the previous allowlist' do
      let(:markup) { '<div style="color:red;display:block;width:1px;height:1px;float:right;--tone:black"></div>' }

      it 'preserves the six-declaration limit' do
        expect(check.issues).to be_empty
      end
    end

    context 'with seven declarations of properties outside the previous allowlist' do
      let(:markup) { '<div style="color:red"></div>' * 7 }

      it 'reports actual inline declarations regardless of property name' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'with seven repeated declarations in one attribute' do
      let(:markup) { '<div style="color:red;color:blue;color:red;color:blue;color:red;color:blue;color:red"></div>' }

      it 'counts every declaration' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'with property names in text, comments, scripts, style blocks and other attributes' do
      let(:markup) do
        <<~HTML
          <p>font-size padding margin background-color border-radius text-align object-fit</p>
          <!-- <div style="color:red;color:red;color:red;color:red;color:red;color:red;color:red"> -->
          <script>const sample = '<div style="font-size:1px">';</script>
          <style>.sample { padding:1px; margin:1px; font-size:1px; text-align:left; }</style>
          <div data-plugin-style="font-size padding margin background-color border-radius text-align object-fit"></div>
        HTML
      end

      it 'does not mistake other source content for inline styles' do
        expect(check.issues).to be_empty
      end
    end

    context 'with styles inside a Liquid comment' do
      let(:markup) { "{%- comment -%}#{'<div style="color:red"></div>' * 7}{%- endcomment -%}" }

      it 'ignores content Liquid does not emit' do
        expect(check.issues).to be_empty
      end
    end

    context 'with CSS comments, strings containing semicolons and HTML entities' do
      let(:markup) { '<div style="/* padding margin */ content: &quot;padding:1px;margin:1px&quot;; color:red"></div>' }

      it 'counts parsed declarations instead of words or semicolons' do
        expect(check.issues).to be_empty
      end
    end

    context 'with mixed-case HTML, single quotes and unquoted attributes' do
      let(:markup) { ("<DIV STYLE='COLOR:red'></DIV>" * 4) + ('<p style=color:blue></p>' * 3) }

      it 'recognizes styles in valid HTML attribute forms' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'with Liquid expressions in declaration values' do
      let(:markup) { '<div style="width:{{ width }}px"></div>' * 7 }

      it 'counts declarations without requiring render data' do
        expect(check.issues).not_to be_empty
      end
    end
  end
end

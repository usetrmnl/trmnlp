---
name: core-parity
description: Check a trmnlp behavior against TRMNL core before changing it — where core builds, renders, captures and quantizes a plugin, and which trmnlp files mirror which core files. Use when a change touches rendering, the screenshot, page scripts, Liquid filters, form field types, dark mode, the page clock, or when someone asks "does TRMNL do this too?".
---

# Checking parity with TRMNL core

Core is the `usetrmnl/core` Rails app. Read its source, not its docs.

| What | trmnlp | core |
|---|---|---|
| Page HTML around the markup | `lib/trmnlp/renderer.rb`, `web/views/render_html.erb` | `app/views/plugins/`, `app/helpers/plugin_helper.rb` |
| Load and capture in Firefox | `lib/trmnlp/screenshot.rb` | `lib/converter/html.rb`, `lib/converter/html/page_scripts.rb` |
| Freezing timers before capture | `Screenshot::FREEZE_TIMERS` | `JS_FREEZE_SCRIPT` |
| Quantizing to the device palette | `lib/trmnlp/image_quantizer.rb` | `lib/converter/magick_wrapper.rb` (`apply_monochrome_filter`) |
| `qr_code` filter | `lib/trmnlp/qr_code.rb` | `config/initializers/trmnl_liquid_qr_code.rb` |
| Dark mode classes | `Renderer#screen_classes` | `plugin_helper.rb` (`screen--dark-mode dark-mode`) |
| Form field types | `db/data/form_fields.yml` | the settings form partials |
| Data for each strategy | `lib/trmnlp/user_data_assembler.rb` | `app/services/plugins/data/private_plugin.rb` |

Known, written-down differences (keep them written down if they change):

- `trmnlp test` opens pages from `http://127.0.0.1:<port>/pages/<id>`; core writes into `about:blank`. Firefox prefs block storage, cookies and the Referer to match.
- Core keeps warm browser slots; trmnlp starts Firefox per run.

Steps:

1. Find the core code for the behavior with the table, then `grep` from there.
2. Reproduce in trmnlp with a tiny plugin and a real Firefox render. Look at the PNG.
3. If core and trmnlp differ, the fix goes to trmnlp unless core is the one with the bug. Then fix core too, in its own PR, and link the two.

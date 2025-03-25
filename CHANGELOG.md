# Changelog

## vNext

- Fix crash when #poll_data fails (#12)
- Fix git runtime error in Docker container (#12)
- Add static strategy
- Add polling features: multiple URLs, new verbs, and request body
- Add `watch_paths` config
- Add `dark_mode` config
- Add `[custom_fields]` config
- Add `{{ trmnl }}` variables
- Add `[trmnl.*]` variable override config
- Add interpolation of custom fields into polling\_\* options
- Add interpolation of environment variables into custom field values via `env` namespace
- Add auto-reload when `config.toml` or `static.json` changes
- Add variable display

## 0.3.2

- Add bitmap rendering
- Add TRMNL's [custom plugin filters](https://help.usetrmnl.com/en/articles/10347358-custom-plugin-filters)
- Add support for user-supplied custom filters

## 0.3.1

- Add live render

## 0.3.0

- Add poll button
- Add case image overlays
- Add `trmnlp build` command
- Add support for `url` pointing to a local JSON data file

## 0.2.0

- Add "commands" concept to `trmnlp` executable
- `trmnlp serve` improvements
  - Add argument for plugin directory
  - Add options `-b` and `-p` for host bind and port, respectively
- Add Dockerfile

## 0.1.2

- Initial working release

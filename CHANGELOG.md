# Changelog

## 0.5.0

- Added `trmlnp init` command
- Added `trmnlp clone` command
- Improved `trmnlp push` to create remote plugin on first publish
- Changed syntax of `trmnlp push` and `trmnlp pull` commands
- Added `oj` gem for JSON parsing (#32)

## 0.4.0

### Plugin Migration Strategy

The plugin directory structure has changed to better align with the [plugin archive format](https://help.usetrmnl.com/en/articles/10542599-importing-and-exporting-private-plugins#h_581fb988f0). 

Here is a migration strategy for existing plugin repositories:

1. Create `.trmnlp.yml` and bring over preview settings from `config.toml` - [see README](README.md)
2. Rename directory `views/` to `src/`
3. Create `src/settings.yml` and bring over plugin settings from `config.toml` - [see TRMNL docs](https://help.usetrmnl.com/en/articles/10542599-importing-and-exporting-private-plugins#h_581fb988f0)
4. Delete `config.toml`

### Changes

- Change plugin directory structure (see README for details)
- Add `login`, `push`, and `pull` commands
- Bring up-to-date with latest private plugin features:
  - Add `static` strategy
  - Add polling features: multiple URLs, new verbs, and request body
  - Add settings `dark_mode`, `no_screen_padding`, `custom_fields`
  - Add interpolation of custom fields in `polling\_\*` options
  - Add `{{ trmnl }}` variables 
- Add `watch` config
- Add interpolation of environment variables in `.trmnlp.yml` via `{{ env }}`
- Add auto-reload when `.trmnlp.yml` or `settings.yml` changes
- Add variable display
- Fix crash when #poll_data fails (#12)
- Fix git runtime error in Docker container (#12)



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

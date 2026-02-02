
# Changelog

## 0.7.0

- Switch from Puppeteer + CDP to Selenium + WebDriver BiDi (@SorceressLyra)

## 0.6.1

- Update trmnl-liquid to 0.4.0

## 0.6.0

- Drop trmnl-component in lieu of plain iframe
- Add [trmnl-picker](https://github.com/usetrmnl/trmnl-picker) to support new TRMNL and BYOD screens
- Fix mashup layout previews

## 0.5.10

- Fix interpolation of multi-line polling URLs with custom fields

## 0.5.9

- Add `pathname` dependency

## 0.5.8

- Improve Docker commands in `bin/trmnlp` (@jrand0m, @jbarreiros)

## 0.5.7

- Use the `trmnl-liquid` gem so tags and filters stay up-to-date with the core offering

## 0.5.6

- Fixed bug that left blank plugins on server after upload failed
- Fixed bug creating upload.zip after previous upload had failed
- Added support to read API key fromk `TRMNL_API_KEY` environment variable (@andi4000)
- Fixed `init` command in Docker container (@jbarreiros)
- Automatically remove ephemeral Docker container after exit (@andi4000)

## 0.5.5

- Added dark mode (@stephenyeargin)
- Added override for `polling_url` in project config (@heroheman)
- Reworked `bin/dev` into more generic `bin/trmnlp`
- Fixed pull, push, and clone commands on Windows (@eugenio)

## 0.5.4

- Added `shared.liquid` file to template (@mariovisic)
- Stringified custom field values to match production (@mariovisic)
- Optimized image generation (@sd416)
- Fixed preview from growing when JSON data becomes too wide (@stephenyeargin)

## 0.5.3

- Added support for [reusable markup](https://docs.trmnl.com/go/reusing-markup) in `shared.liquid`
- Replaced custom case images with [\<trmnl-frame\> component](https://github.com/usetrmnl/trmnl-component)
- Updated custom Liquid filters
- Added API key validation during `trmnlp login`

## 0.5.2

- Added `time_zone` project config option, which is injected into `trmnl.user` variables
- Fixed time zone to always be UTC, matching trmnl.com servers (#38)

## 0.5.1

- Fixed `trmnl init`

## 0.5.0

- Added `trmlnp init` command
- Added `trmnlp clone` command
- Improved `trmnlp push` to create remote plugin on first publish
- Changed syntax of `trmnlp push` and `trmnlp pull` commands
- Added `oj` gem for JSON parsing (#32)

## 0.4.0

### Plugin Migration Strategy

The plugin directory structure has changed to better align with the [plugin archive format](https://help.trmnl.com/en/articles/10542599-importing-and-exporting-private-plugins#h_581fb988f0). 

Here is a migration strategy for existing plugin repositories:

1. Create `.trmnlp.yml` and bring over preview settings from `config.toml` - [see README](README.md)
2. Rename directory `views/` to `src/`
3. Create `src/settings.yml` and bring over plugin settings from `config.toml` - [see TRMNL docs](https://help.trmnl.com/en/articles/10542599-importing-and-exporting-private-plugins#h_581fb988f0)
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
- Add TRMNL's [custom plugin filters](https://help.trmnl.com/en/articles/10347358-custom-plugin-filters)
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

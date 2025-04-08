# trmnlp

A basic self-hosted web server to ease the development and sharing of [TRMNL](https://usetrmnl.com/) plugins.

[Liquid](https://shopify.github.io/liquid/) templates are rendered leveraging the [TRMNL Design System](https://usetrmnl.com/framework). They may be generated as HTML (faster, and a good approximation of the final result) or as BMP images (slower, but more accurate).

The server watches the filesystem for changes to the Liquid templates, seamlessly updating the preview without the need to refresh.

![Screenshot](docs/preview.png)

## Creating a Plugin

This is the structure of a plugin repository.

```
src/
    full.liquid
    half_horizontal.liquid
    half_vertical.liquid
    quadrant.liquid
    settings.yml
.trmnlp.yml (optional)
```

The [trmnl-hello](https://github.com/schrockwell/trmnl-hello) repository is provided as a jumping-off point for creating new plugins. Simply fork the repo, clone it, and start hacking.

## Running the Server (Docker)

```sh
docker run \
    -p 4567:4567 \
    -v /path/to/plugin/on/host:/plugin \
    schrockwell/trmnlp
```

## Running the Server (Local Ruby)

Prerequisites:

- Ruby 3.x
- For BMP rendering (optional):
  - Firefox
  - ImageMagick

In the plugin repository:

```sh
gem install trmnl_preview
trmnlp serve                # Starts the server
```

## `./.trmnlp.yml` Reference

The `.trmnlp.yml` file lives in the root of the plugin repository, and is for configuring the local dev server.

System environment variables are made available in the `{{ env }}` Liquid varible in this file only. This can be used to safely
supply plugin secrets, like API keys.

All fields are optional.

```yaml
# {{ env.VARIABLE }} interpolation is available here
---
# enable auto-refresh when files change
live_render: true

# additional path globs to watch for changes
watch_paths:
  - src/**/*

# values of custom fields (the fields are defined in settings.yml)
custom_fields:
  station: "{{ env.ICAO }}"

# override any variable
variables:
  trmnl:
    user:
      name: Peter Quill
    plugin_settings:
      instance_name: Kevin Bacon Facts

```

## `./src/settings.yml` Reference

The `settings.yml` file is part of the private plugin definition. 

See [TRMNL documentation](https://help.usetrmnl.com/en/articles/10542599-importing-and-exporting-private-plugins#h_581fb988f0) for details on the format of this file.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/usetrmnl/trmnlp.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

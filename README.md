# trmnl_preview

A little self-hosted web server executable, `trmlp`, to ease the development and sharing of [TRMNL](https://usetrmnl.com/) plugins.

This gem enables local development of plugins using Liquid templates, so that you can quickly iterate on designs before finally pasting the markup into the private plugin in TRMNL's dashboard.

The plain HTML preview is generated using the [TRMNL Design System](https://usetrmnl.com/framework). It does NOT generate a rendered BMP file. Hence, this is just a _preview_ of the final rendered dashboard.

![Screenshot](docs/preview.png)

## Prerequisites

- Ruby 3.x

## Starter Plugin

The [trmnl-hello](https://github.com/schrockwell/trmnl-hello) repository is provided as a jumping-off point for creating new plugins. Simply fork the repo, clone it, and start hacking.

## Creating a Plugin

Your plugin repository should have the following structure:

```
views/
    full.liquid
    half_horizontal.liquid
    half_vertical.liquid
    quadrant.liquid
Gemfile
config.toml
```

To create the `Gemfile`, simply `bundle add trmnl_preview`.

See [config.example.toml](config.example.toml) for an example config.

Then run `trmnlp` from the repository root, and visit http://127.0.0.1:4567

## Usage Notes

Simply refresh the page to re-render.

When the strategy is "polling", the specified URL will be fetched once, when the server starts.

When the strategy is "webhook", you can POST payloads to the `/webhook` endpoint. They are saved to `tmp/data.json` for future renders.

## `config.toml` Reference

- `strategy` - Either "polling" or "webhook"
- `url` - The URL from which to fetch JSON data (polling strategy only)
- `[polling_headers]` - A section of headers to append to the HTTP poll request (polling strategy only)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/schrockwell/trmnl_preview.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

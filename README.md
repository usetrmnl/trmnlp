# trmnl_preview

A little self-hosted web server executable, `trmlp`, to ease the development and sharing of [TRMNL](https://usetrmnl.com/) plugins.

This gem enables local development of plugins using Liquid templates, so that you can quickly iterate on designs before finally pasting the markup into the private plugin in TRMNL's dashboard.

The plain HTML preview is generated using the [TRMNL Design System](https://usetrmnl.com/framework). It does NOT generate a rendered BMP file. Hence, this is just a _preview_ of the final rendered dashboard.

![Screenshot](docs/preview.png)

## Prerequisites

- Ruby 3.x

## Getting Started

Clone a fork of https://github.com/schrockwell/trmnl-hello.

Run `bundle` to install dependencies.

Modify `config.toml` (see below for reference) for your use-case.

Modify the four view templates in `views/*.liquid`

Run `trmnlp` to start the local web server.

Browse it locally at http://127.0.0.1:4567/

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

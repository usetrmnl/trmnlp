# trmnl_preview

A little self-hosted web server to ease the development and sharing of [TRMNL](https://usetrmnl.com/) plugins.

## Prerequisites

- Ruby 3.x

## Getting Started

Clone a fork of https://github.com/schrockwell/trmnl-hello.

Run `bundle`.

Modify `config.toml` (see below for reference).

Modify the four view templates in `views/*.liquid`

Run `trmnlp` to start the local web server.

Browse it locally at http://127.0.0.1:4567/

## Usage Notes

Simply refresh the page to re-render.

When the polling strategy is "polling", the specified URL will be fetched once when the server starts.

When the polling strategy is "webhook", you can POST payloads to the `/webhook` endpoint. They are saved to `tmp/data.json` for future renders.

## `config.toml` Reference

- `strategy` - Either "polling" or "webhook"
- `url` - The URL from which to fetch JSON data (polling strategy only)
- `[polling_headers]` - A section of headers to append to the HTTP poll request (polling strategy only)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/schrockwell/trmnl_preview.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

# trmnlp

A basic self-hosted web server to ease the development and sharing of [TRMNL](https://usetrmnl.com/) plugins.

[Liquid](https://shopify.github.io/liquid/) templates are rendered leveraging the [TRMNL Design System](https://usetrmnl.com/framework). They may be generated as HTML (faster, and a good approximation of the final result) or as BMP images (slower, but more accurate).

The server watches the filesystem for changes to the Liquid templates, seamlessly updating the preview without the need to refresh.

![Screenshot](docs/preview.png)

## Creating a Plugin

This is the structure of a plugin repository.

```
views/
    full.liquid
    half_horizontal.liquid
    half_vertical.liquid
    quadrant.liquid
config.toml
static.json # optional; for static strategy
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

## Usage Notes

When the strategy is "polling", the specified URL will be fetched once, when the server starts.

When the strategy is "webhook", payloads can be POSTed to the `/webhook` endpoint. They are saved to `tmp/data.json` for future renders.

When the strategy is "static", the data is read from `static.json`.

## `config.toml` Reference

```toml
# "polling" => fetches remote data from polling_urls
# "webhook" => listens for POST data at /webhook
# "static"  => reads from static.json
strategy = "polling"

# (polling strategy) URLs to poll
polling_urls = ["https://example.com/data.json"]

# (polling strategy) HTTP verb to poll the URL (default: "GET")
polling_verb = "GET"

# (polling strategy) body payload, useful for GraphQL (default: "")
polling_body = "{ stats { mean median mode } }"

# enable dark mode (string value "yes" or "no", default: "no")
dark_mode = "no"

# (static strategy) The local file to read (default: "static.json")
static_path = "static.json"

# automatically re-render the view when Liquid templates change (default: true)
live_render = true

# additional file globs to watch for changes (default: [])
watch_paths = ["src/**/*"]

# (polling strategy) HTTP headers
[polling_headers]
Authorization = "bearer 123"
Content-Type = "application/json"
Accept = "applcation/json"

# values for any custom fields - can be interpolated into polling_{urls,body,headers}
[custom_fields]
units = "metric"
api_key="{{ env.API_KEY }}" # interpolated from local environment variable

# override default values in the {{ trmnl }} namespace
[trmnl.user]
name = "Peter Quill"

[trmnl.plugin_settings]
instance_name = "Kevin Bacon Facts"
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/schrockwell/trmnl_preview.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

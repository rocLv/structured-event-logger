# StructuredEventLogger

Structured event logger that writes events to both a human readable log and a JSON formatted log

## Installation

Add this line to your application's Gemfile:

    gem 'structured-event-logger'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install structured-event-logger

## Usage

    # Creating an instance
    json_logger = File.open(Rails.root.join("log", "event.log"), "a")
    human_readable_logger = Rails.logger
    event_logger = StructuredEventLogger.new(json_logger, human_readable_logger)

    # Basic usage
    event_logger.event('scope', event, field: 'value', other_field: 'other value')

    # Add context per thread/request (e.g. in an around_filter)
    around_filter do
      event_logger.context[:my_value] = 'whatever'
      yield
      event_logger.context.delete(:my_value)
    end

    # later, while processing a request inside that filter
    event_logger.event('scope', 'event', other_value: 'blah') # will also include { my_value: 'whatever' }

## Fields

The default event fields that this library sets are prefixed with `event_`:

- `event_scope`: scope of the event, the first parameter to the `event` call.
- `event_name`: name of the event, the second parameter to the `event` call.
- `event_uuid`: A unique identifier for the event generated using `SecureRandom.uuid`.
- `event_timestamp`: The timestamp of the event, set to `Time.now.utc`.

All these fields can be overriden by passing new values to the context hash, i.e. the
third parameter to the `event` call.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

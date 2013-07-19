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
    human_readable_logger = Rails.logger
    json_logger = Logger.new('events.log')
    event_logger = StructuredEventLogger.new(human_readable_logger, json_logger)

    # Usage
    event_logger.event('scope', event)
  
## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

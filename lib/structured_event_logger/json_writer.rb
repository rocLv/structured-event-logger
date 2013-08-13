require 'multi_json'
require 'active_support/json'

class StructuredEventLogger::JsonWriter

  attr_reader :io

  def initialize(io)
    @io = io
  end

  def log_event(scope, event, hash, record)
    io.write(MultiJson.encode(record) + "\n")
  end
end

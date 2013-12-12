require 'active_support/json'

class StructuredEventLogger::JsonWriter

  attr_reader :io

  def initialize(io)
    @io = io
  end

  def call(scope, event, hash, record)
    io.write(ActiveSupport::JSON.encode(record) + "\n")
  end
end

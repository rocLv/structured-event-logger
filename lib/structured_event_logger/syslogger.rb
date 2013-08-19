require 'multi_json'
require 'active_support/json'
require 'syslog'

class StructuredEventLogger::Syslogger

  class MessageExceedsMaximumSize < StructuredEventLogger::Error; end

  attr_accessor :log_level, :max_size

  def initialize(log_level = Syslog::LOG_INFO, max_size = (64 * 1024 - 1))
    @log_level, @max_size = log_level, max_size
  end

  def call(scope, event, hash, record)
    message = MultiJson.encode(record)
    raise MessageExceedsMaximumSize, "Event to big to be submitted to syslog" if message.bytesize > max_size
    Syslog.log(log_level, '%s', message)
  end
end

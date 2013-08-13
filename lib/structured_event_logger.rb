require 'securerandom'

class StructuredEventLogger
  CLEAR   = "\e[0m"
  BOLD    = "\e[1m"

  # Colors
  MAGENTA = "\e[35m"
  CYAN    = "\e[36m"
  WHITE   = "\e[37m"

  attr_reader :endpoints, :default_context

  def initialize(json_io = nil, unstructured_logger = nil)
    @endpoints = []

    @endpoints << StructuredEventLogger::JsonEndpoint.new(json_io) if json_io
    @endpoints << StructuredEventLogger::HumanReadableLoggerEndpoint.new(unstructured_logger) if unstructured_logger

    @thread_contexts = {}
    @default_context = {}
  end

  def event(scope, event, content = {})
    log_event scope, event, flatten_hash(content)
  end

  def context
    @thread_contexts[thread_key] ||= {}
  end

  private

  def flatten_hash(hash, keys = nil, separator = "_")
    flat_hash = {}
    hash.each_pair do |key, val|
      conc_key = keys.nil? ? key : "#{keys}#{separator}#{key}"
      if val.is_a?(Hash)
        flat_hash.merge!(flatten_hash(val, conc_key))
      else
        flat_hash[conc_key] = val
      end
    end
    flat_hash
  end

  def log_event(scope, event, hash)
    record = @default_context.merge(context)
    record.update(event_name: event, event_scope: scope, event_uuid: SecureRandom.uuid, event_timestamp: Time.now.utc)
    record.update(hash)

    endpoints.each do |endpoint|
      begin
        endpoint.log_event(scope, event, hash, record)
      rescue => e
        # noop
      end
    end
  end

  def thread_key
    Thread.current
  end
end

require 'structured_event_logger/json_endpoint'
require 'structured_event_logger/human_readable_logger_endpoint'

require 'securerandom'

class StructuredEventLogger

  class Error < ::StandardError; end

  class EventHandlingException < StructuredEventLogger::Error
    attr_reader :exceptions
    def initialize(scope, name, exceptions)
      @scope, @name, @exceptions = scope, name, exceptions
      super("Failed to submit the #{scope}/#{name} event to the following endpoints: #{exceptions.keys.join(", ")}")
    end
  end

  attr_reader :endpoints, :default_context

  attr_accessor :only
  attr_accessor :error_handler

  def initialize(endpoints = {})
    @endpoints = endpoints

    @thread_contexts = {}
    @default_context = {}

    @error_handler = lambda { |exception| raise(exception) }
  end

  def event(scope, event, content = {})
    return unless @only.nil? || @only.call(scope, event, content)
    log_event scope, event, flatten_hash(content)
  rescue EventHandlingException => e
    error_handler.call(e)
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

    exceptions = {}
    endpoints.each do |name, endpoint|
      begin
        endpoint.call(scope, event, hash, record)
      rescue => e
        exceptions[name] = e
      end
    end

    raise EventHandlingException.new(scope, event, exceptions) unless exceptions.empty?
    record
  end

  def thread_key
    Thread.current
  end
end

require 'structured_event_logger/syslogger'
require 'structured_event_logger/json_writer'
require 'structured_event_logger/human_readable_logger'

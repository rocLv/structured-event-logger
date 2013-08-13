require 'securerandom'

class StructuredEventLogger
  attr_reader :endpoints, :default_context

  def initialize(endpoints = [])
    @endpoints = endpoints

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
        endpoint.call(scope, event, hash, record)
      rescue => e
        $stderr.write("Failed to submit event #{scope}/#{event} to #{endpoint.inspect}: #{e.message}.\n")
      end
    end
  end

  def thread_key
    Thread.current
  end
end

require 'structured_event_logger/json_writer'
require 'structured_event_logger/human_readable_logger'

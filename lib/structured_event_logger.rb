require 'logger'
require 'active_support/json'

class StructuredEventLogger
  
  attr_reader :json_logger, :unstructured_logger

  def initialize(json_logger, unstructured_logger = nil)
    @json_logger, @unstructured_logger = json_logger, unstructured_logger
    @thread_contexts = {}
  end

  def log(msg = nil)
    unstructured_logger.add(nil, msg)
  end

  def event(scope, event, content = {})
    log_event({:scope => scope, :event => event}.merge(flatten_hash(content)))
  end

  def context
    @thread_contexts[thread_key] ||= {}
  end

  private

  def format_hash(hash, separator = ', ')
    "[Event Logger] " + hash.map {|k, v| "#{k}=#{escape(v)}"}.join(separator)
  end

  def escape(value)
    output = value.to_s
    if output =~ /[\s"\\]/
      '"' + output.gsub('\\', '\\\\\\').gsub('"', '\\"') + '"'
    else
      output
    end
  end

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

  def log_event(hash)
    unstructured_logger.add(nil, format_hash(hash)) if unstructured_logger
    hash = hash.merge(context)
    hash[:timestamp] ||= Time.now.utc
    json_logger.add(nil, MultiJson.encode(hash))
  end

  def thread_key
    Thread.current
  end
end

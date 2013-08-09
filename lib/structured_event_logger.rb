require 'logger'
require 'securerandom'
require 'active_support/json'
require 'active_support/log_subscriber'

class StructuredEventLogger
  CLEAR   = "\e[0m"
  BOLD    = "\e[1m"

  # Colors
  MAGENTA = "\e[35m"
  CYAN    = "\e[36m"
  WHITE   = "\e[37m"

  attr_reader :json_io, :unstructured_logger, :colorize_logging, :default_context

  def initialize(json_io, unstructured_logger = nil)
    @json_io, @unstructured_logger = json_io, unstructured_logger
    @thread_contexts = {}
    @default_context = {}
    @colorize_logging = ActiveSupport::LogSubscriber.colorize_logging
  end

  def log(msg = nil)
    unstructured_logger.add(nil, msg)
  end

  def event(scope, event, content = {})
    log_event scope, event, flatten_hash(content)
  end

  def context
    @thread_contexts[thread_key] ||= {}
  end

  private

  def format_hash(scope, event, hash, separator = ', ')
    @odd = !@odd
    message = hash.map {|k, v| "#{k}=#{escape(v)}"}.join(separator)
    if @colorize_logging
      "  #{@odd ? CYAN : MAGENTA}#{BOLD}[#{scope}] #{event}: #{WHITE}#{message}#{CLEAR}"
    else
      "  [#{scope}] #{event}: #{message}"
    end
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

  def log_event(scope, event, hash)
    unstructured_logger.add(nil, format_hash(scope, event, hash)) if unstructured_logger

    hash = hash.merge(@default_context.merge(context)).merge(event: event, scope: scope)
    hash = { timestamp: Time.now.utc, event_uuid: SecureRandom.uuid }.merge(hash)
    json_io.write("#{MultiJson.encode(hash)}\n")
  end

  def thread_key
    Thread.current
  end
end

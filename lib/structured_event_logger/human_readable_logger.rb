require 'active_support/log_subscriber'

class StructuredEventLogger::HumanReadableLogger

  CLEAR   = "\e[0m"
  BOLD    = "\e[1m"

  # Colors
  MAGENTA = "\e[35m"
  CYAN    = "\e[36m"
  WHITE   = "\e[37m"
   
  attr_accessor :logger, :colorize, :log_level

  def initialize(logger, colorize = ActiveSupport::LogSubscriber.colorize_logging, log_level = nil)
    @logger, @colorize, @log_level = logger, colorize, log_level
  end


  def call(scope, event, hash, decorated_hash)
    logger.add(log_level, format_hash(scope, event, hash))
  end

  private

  def format_hash(scope, event, hash, separator = ', ')
    @odd = !@odd
    message = hash.map {|k, v| "#{k}=#{escape(v)}"}.join(separator)
    if @colorize
      "  #{@odd ? CYAN : MAGENTA}#{BOLD}[#{scope}] #{event}: #{WHITE}#{message}#{CLEAR}"
    else
      "  [#{scope}] #{event}: #{message}"
    end
  end

  def escape(value)
    output = value.to_s
    output =~ /[\s"\\]/ ? output.inspect : output
  end
end

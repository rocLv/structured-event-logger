require 'test_helper'
require 'stringio'
require 'time'

class StructuredEventLoggerTest < Minitest::Test
  def setup
    ActiveSupport::LogSubscriber.colorize_logging = false
    @json_logger     = Logger.new(STDOUT)
    @buffered_logger = Logger.new(STDOUT)
    @event_logger    = StructuredEventLogger.new(@json_logger, @buffered_logger)
    @time = Time.parse('2012-01-01')
  end

  def test_should_log_msg_to_buffered_logger
    @buffered_logger.expects(:add).with(nil, "a message")
    @json_logger.expects(:add).never

    @event_logger.log "a message"
  end

  def test_should_log_event_to_both_loggers
    Timecop.travel(@time) do
      @buffered_logger.expects(:add).with(nil, "  [render] error: status=status, message=message")
      @json_logger.expects(:add).with(nil, "{\\'status\\':\\'status\\',\\'message\\':\\'message\\',\\'event\\':\\'error\\',\\'scope\\':\\'render\\',\\'timestamp\\':\\'#{Time.now.utc.strftime('%FT%TZ')}\\'}")

      @event_logger.event "render", "error", {:status => "status", :message => "message"}
    end
  end

  def test_should_log_flatten_hash
    Timecop.travel(@time) do
      @buffered_logger.expects(:add).with(nil, "[Event Logger] scope=render, event=error, status=status, message_first=first, message_second=second")
      @json_logger.expects(:add).with(nil, "\\'scope\':\'render\',\'event\':\'error\',\'status\':\'status\',\'message\':\'message\',\'timestamp\':\'#{Time.now.utc.strftime('%FT%TZ')}\'}")
      @event_logger.event "render", "error", {:status => "status", :message => {:first => "first", :second => "second"}}
    end
  end

  def test_should_log_to_current_context
    Timecop.travel(@time) do
      @json_logger.expects(:add).with(nil, "{\\'request_id\\':\\'2\\',\\'event\\':\\'error\\',\\'scope\\':\\'render\\',\\'timestamp\\':\\'2012-01-01T05:00:00Z\\'}")
      
      Thread.new do 
        @event_logger.context[:request_id] = '1'

        Thread.new do 
          @event_logger.context[:request_id] = '2'
          @event_logger.event :render, :error
        end.join
      end.join
    end
  end

  def test_should_delete_context
    
    Timecop.travel(@time) do
      order = sequence('log message order')
      @json_logger.expects(:add).with(nil, "{\"scope\":\"render\",\"event\":\"error\",\"request_id\":\"1\",\"timestamp\":\"#{Time.now.utc.strftime('%FT%TZ')}\"}").in_sequence(order)
      @json_logger.expects(:add).with(nil, "{\"scope\":\"render\",\"event\":\"error\",\"timestamp\":\"#{Time.now.utc.strftime('%FT%TZ')}\"}").in_sequence(order)
      
      Thread.new do 
        @event_logger.context[:request_id] = '1'
        @event_logger.event :render, :error
        @event_logger.context.clear
      end.join

      @event_logger.event :render, :error
    end
  end
end


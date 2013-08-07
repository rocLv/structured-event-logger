require 'test_helper'
require 'stringio'

class StructuredEventLoggerTest < Minitest::Test
  def setup
    ActiveSupport::LogSubscriber.colorize_logging = false

    @json_io = StringIO.new
    @unstructured_logger = Logger.new(@nonstructured_io = StringIO.new)
    @unstructured_logger.formatter = proc { |_, _, _, msg| "#{msg}\n" }
    @event_logger = StructuredEventLogger.new(@json_io, @unstructured_logger)
    @time = Time.parse('2012-01-01')
  end

  def test_should_log_msg_to_buffered_logger
    @event_logger.log "a message"
    assert_equal "a message\n", @nonstructured_io.string
    assert @json_io.string.empty?
  end

  def test_should_log_event_to_both_loggers
    Timecop.travel(@time) do
      @event_logger.event "render", "error", {:status => "status", :message => "message"}
      assert_equal "{\"status\":\"status\",\"message\":\"message\",\"event\":\"error\",\"scope\":\"render\",\"timestamp\":\"2012-01-01T05:00:00Z\"}\n", @json_io.string
      assert_equal "  [render] error: status=status, message=message\n", @nonstructured_io.string
    end
  end

  def test_should_log_flatten_hash
    Timecop.travel(@time) do
      @event_logger.event "render", "error", {:status => "status", :message => {:first => "first", :second => "second"}}

      assert_equal "{\"status\":\"status\",\"message_first\":\"first\",\"message_second\":\"second\",\"event\":\"error\",\"scope\":\"render\",\"timestamp\":\"2012-01-01T05:00:00Z\"}\n", @json_io.string
      assert_equal "  [render] error: status=status, message_first=first, message_second=second\n", @nonstructured_io.string      
    end
  end

  def test_should_log_to_current_context
    Timecop.travel(@time) do
      Thread.new do 
        @event_logger.context[:request_id] = '1'

        Thread.new do 
          @event_logger.context[:request_id] = '2'
          @event_logger.event :render, :error
        end.join
      end.join
    end

    assert_equal "{\"request_id\":\"2\",\"event\":\"error\",\"scope\":\"render\",\"timestamp\":\"2012-01-01T05:00:00Z\"}\n", @json_io.string
  end

  def assert_event_contains_value(value, key)
    @event_logger.event :some_scope, :some_event
    assert_equal value, JSON.parse(@json_io.string)[key.to_s]
  end

  def test_default_context_gets_merged
    @event_logger.default_context[:foo] = 42
    assert_event_contains_value 42, :foo
  end

  def test_default_context_values_can_be_overriden
    @event_logger.default_context[:foo] = 42
    @event_logger.context[:foo] = 43
    assert_event_contains_value 43, :foo
  end

  def test_default_context_gets_merged_again_after_clear
    @event_logger.default_context[:foo] = 42
    @event_logger.context.clear
    assert_event_contains_value 42, :foo
  end

  def test_should_clear_context
    Timecop.travel(@time) do
      Thread.new do
        @event_logger.context[:request_id] = '1'
        @event_logger.event :render, :in_thread
        @event_logger.context.clear
      end.join

      @event_logger.event :render, :out_thread

      log_lines = @json_io.string.lines.entries
      assert_equal "{\"request_id\":\"1\",\"event\":\"in_thread\",\"scope\":\"render\",\"timestamp\":\"2012-01-01T05:00:00Z\"}\n", log_lines[0]
      assert_equal "{\"event\":\"out_thread\",\"scope\":\"render\",\"timestamp\":\"2012-01-01T05:00:00Z\"}\n", log_lines[1]
    end
  end
end


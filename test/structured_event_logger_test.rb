require 'test_helper'
require 'stringio'

class StructuredEventLoggerTest < Minitest::Test
  def setup
    ActiveSupport::LogSubscriber.colorize_logging = false

    @unstructured_logger = Logger.new(@nonstructured_io = StringIO.new)
    @unstructured_logger.formatter = proc { |_, _, _, msg| "#{msg}\n" }

    @event_logger = StructuredEventLogger.new(
      logger: StructuredEventLogger::HumanReadableLogger.new(@unstructured_logger),
      json:   StructuredEventLogger::JsonWriter.new(@json_io = StringIO.new)
    )

    Time.stubs(:now).returns(Time.parse('2012-01-01T05:00:00Z'))
    SecureRandom.stubs(:uuid).returns('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee')
    Syslog.open('test_structured_event_logger') unless Syslog.opened?
  end

  def teardown
    Syslog.close
  end

  def test_should_log_event_to_both_loggers
    @event_logger.event "render", "error", {:status => "status", :message => "message"}

    assert_equal "  [render] error: status=status, message=message\n", @nonstructured_io.string
    assert @json_io.string.end_with?("\n")
    assert_kind_of Hash, JSON.parse(@json_io.string)
  end

  def test_default_json_properties
    @event_logger.event :render, :error

    assert_last_event_contains_value 'render', :event_scope
    assert_last_event_contains_value 'error', :event_name
    assert_last_event_contains_value 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', :event_uuid
    assert_last_event_contains_value '2012-01-01T05:00:00Z', :event_timestamp
  end

  def test_overwriting_default_properties_using_hash
    @event_logger.event :original, :original, :event_scope => 'overwritten', :event_name => 'overwritten',
            :event_timestamp => Time.parse('1912-01-01T04:00:00Z'), :event_uuid => 'overwritten'

    assert_last_event_contains_value 'overwritten', :event_scope
    assert_last_event_contains_value 'overwritten', :event_name
    assert_last_event_contains_value 'overwritten', :event_uuid
    assert_last_event_contains_value '1912-01-01T04:00:00Z', :event_timestamp
  end

  def test_overwriting_default_properties_using_context
    @event_logger.default_context[:event_name] = 'overwritten'
    Thread.new do
      @event_logger.context[:event_scope] = 'overwritten'
      @event_logger.event :original, :original
    end.join

    assert_last_event_contains_value 'original', :event_scope
    assert_last_event_contains_value 'original', :event_name
  end

  def test_should_log_flatten_hash
    @event_logger.event "render", "error", {:status => "status", :message => {:first => "first", :second => "second"}}

    assert_equal "  [render] error: status=status, message_first=first, message_second=second\n", @nonstructured_io.string
    assert_last_event_contains_value 'first',  :message_first
    assert_last_event_contains_value 'second', :message_second
    assert_last_event_contains_value 'status', :status
  end

  def test_should_log_to_current_context
    Thread.new do 
      @event_logger.context[:request_id] = '1'

      Thread.new do 
        @event_logger.context[:request_id] = '2'
        @event_logger.event :render, :error
      end.join
    end.join

    assert_last_event_contains_value '2', :request_id
  end

  def test_default_context_gets_merged
    @event_logger.default_context[:foo] = 42
    @event_logger.event :some_scope, :some_event
    assert_last_event_contains_value 42, :foo
  end

  def test_default_context_values_can_be_overriden
    @event_logger.default_context[:foo] = 42
    @event_logger.context[:foo] = 43
    @event_logger.event :some_scope, :some_event
    assert_last_event_contains_value 43, :foo
  end

  def test_default_context_gets_merged_again_after_clear
    @event_logger.default_context[:foo] = 42
    @event_logger.context.clear
    @event_logger.event :some_scope, :some_event
    assert_last_event_contains_value 42, :foo
  end

  def test_should_clear_context
    Thread.new do
      @event_logger.context[:request_id] = '1'
      @event_logger.event :render, :in_thread
      @event_logger.context.clear
    end.join

    assert_last_event_contains_value '1', :request_id

    @event_logger.event :render, :out_thread
    log_lines = @json_io.string.lines.entries

    assert_last_event_does_not_contain :request_id
  end

  def test_should_submit_events_to_syslog
    Syslog.expects(:log).with do |log_level, format_string, argument|
      event_data = JSON.parse(argument)
      assert_equal Syslog::LOG_INFO, log_level
      assert_equal '%s', format_string
      assert_equal 'test', event_data['event_scope']
      assert_equal 'syslog', event_data['event_name']
      assert_equal 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee', event_data['event_uuid']
      assert_equal '2012-01-01T05:00:00Z', event_data['event_timestamp']
      assert_equal 'test', event_data['message']
    end

    @event_logger.endpoints[:syslog] = StructuredEventLogger::Syslogger.new
    @event_logger.event(:test, :syslog, message: 'test')
  end

  def test_should_fail_when_syslog_message_is_too_large
    @event_logger.endpoints[:syslog] = StructuredEventLogger::Syslogger.new
    assert_raises(StructuredEventLogger::EventHandlingException) do
      @event_logger.event(:test, :syslog, message: 'a' * (64 * 1024 + 1))
    end
  end

  def test_should_raise_exception_when_endpoint_fails
    @event_logger.endpoints[:failer] = proc { raise "FAIL" }
    assert_raises(StructuredEventLogger::EventHandlingException) do
      @event_logger.event(:test, :fail)
    end
  end

  def test_should_execute_a_custom_error_handler_on_failure
    @event_logger.endpoints[:failer1] = proc { raise "FAIL" }
    @event_logger.endpoints[:failer2] = proc { raise "FAIL" }
    @event_logger.error_handler = mock()
    @event_logger.error_handler.expects(:call).with do |exception|
      assert_kind_of StructuredEventLogger::EventHandlingException, exception
      assert_equal 'Failed to submit the test/fail event to the following endpoints: failer1, failer2', exception.message
      assert_equal 2, exception.exceptions.size
      assert_equal 'FAIL', exception.exceptions[:failer1].message
      assert_kind_of RuntimeError, exception.exceptions[:failer2]
    end
    @event_logger.event(:test, :fail)
  end

  def test_only_if
    @event_logger.only_if = lambda { |*args| return false }
    @event_logger.event(:dont_do_it, :foobar)
    assert_nil last_event

    @event_logger.only_if = lambda{ |scope, event, content| scope == :do_it }
    @event_logger.event(:dont_do_it, :foobar)
    assert_nil last_event

    @event_logger.only_if = lambda{ |scope, event, content| scope == :do_it }
    @event_logger.event(:do_it, :foobar)
    assert_last_event_contains_value "do_it", "event_scope"
  end

  private

  def assert_last_event_contains_value(value, key)
    assert_equal value, last_parsed_event[key.to_s]
  end

  def assert_last_event_does_not_contain(key)
    assert !last_parsed_event.has_key?(key.to_s)
  end

  def last_event
    @json_io.string.lines.entries[-1]
  end

  def last_parsed_event
    JSON.parse(last_event)
  end
end

require 'test_helper'
require 'stringio'

class StructuredEventLoggerTest < Minitest::Test
  def setup
    ActiveSupport::LogSubscriber.colorize_logging = false
    
    @unstructured_logger = Logger.new(@nonstructured_io = StringIO.new)
    @unstructured_logger.formatter = proc { |_, _, _, msg| "#{msg}\n" }
    
    @event_logger = StructuredEventLogger.new([
      StructuredEventLogger.json_writer(@json_io = StringIO.new),
      StructuredEventLogger.human_readable_logger(@unstructured_logger),
    ])
    
    Time.stubs(:now).returns(Time.parse('2012-01-01T05:00:00Z'))
    SecureRandom.stubs(:uuid).returns('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee')
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

  private 

  def assert_last_event_contains_value(value, key)
    assert_equal value, last_parsed_event[key.to_s]
  end

  def assert_last_event_does_not_contain(key)
    assert !last_parsed_event.has_key?(key.to_s)
  end

  def last_parsed_event
    JSON.parse(@json_io.string.lines.entries[-1])
  end
end

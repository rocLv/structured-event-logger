require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/pride'
require 'timecop'

$LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))
require 'structured_event_logger'

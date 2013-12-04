# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'structured_event_logger/version'

Gem::Specification.new do |spec|
  spec.name          = "structured-event-logger"
  spec.version       = StructuredEventLogger::VERSION
  spec.authors       = ["Emilie Noel", "Aaron Olson", "Willem van Bergen", "Florian Weingarten"]
  spec.email         = ["willem@shopify.com"]
  spec.description   = %q{Structured event logging interface}
  spec.summary       = %q{Structured event logger that writes events to both a human readable log and a JSON formatted log}
  spec.homepage      = "https://github.com/Shopify/structured-event-logger"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "activesupport", "~> 3.2"
  spec.add_runtime_dependency "multi_json"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 4.2"
  spec.add_development_dependency "mocha", "~> 0.14"
end

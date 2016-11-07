# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'google_drive_transfer/version'

Gem::Specification.new do |spec|
  spec.name          = "google_drive_transfer"
  spec.version       = GoogleDriveTransfer::VERSION
  spec.authors       = ["tanukiti1987"]
  spec.email         = ["tanukiti1987@gmail.com"]

  spec.description   = %q{Tool for google drive data transfering to another google account.}
  spec.summary       = spec.description
  spec.homepage      = "https://github.com/tanukiti1987/google_drive_transfer/"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "google_drive", "~> 2.1"
  spec.add_dependency "parallel", "~> 1.9"
  spec.add_dependency "thor"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "pry"
end

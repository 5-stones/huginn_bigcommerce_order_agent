# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "huginn_bigcommerce_order_agent"
  spec.version       = "1.2.1"
  spec.authors       = ["5 Stones"]
  spec.email         = ["it@weare5stones.com"]

  spec.summary       = %q{Agent that fetches order data from BigCommerce.}
  spec.description   = %q{A no-frills agent to consolidate API requests and return BigCommerce Order data as a single JSON object.}

  spec.homepage      = "https://github.com/5-stones/huginn_bigcommerce_order_agent"


  spec.files         = Dir['LICENSE.txt', 'lib/**/*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = Dir['spec/**/*.rb'].reject { |f| f[%r{^spec/huginn}] }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency "huginn_agent"
end

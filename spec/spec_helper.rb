require "rubygems"
require 'rack/test'
gem 'webrat', '= 0.5.0'
require "webrat"
module AppHelper; def app() Sinatra::Application end end

Spec::Runner.configure do |config|
  config.include Rack::Test::Methods
  config.include Webrat::Methods
  config.include Webrat::Matchers
  config.include AppHelper
end

require File.dirname(__FILE__) + '/../spec_helper'
require "sinatra"
Sinatra::Application.set :environment, :test
require File.dirname(__FILE__) + '/../../cod2web'

# require 'webrat'
# require 'rack/test'

Webrat.configure do |config| config.mode = :rack end

describe 'Pocetna' do
  it 'treba biti login forma' do
    visit "/"
    response_body.should contain 'Login:'
    response_body.should contain 'Signup'
  end
end

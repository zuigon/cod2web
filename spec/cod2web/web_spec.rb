require File.dirname(__FILE__) + '/../spec_helper'
require "sinatra"
Sinatra::Application.set :environment, :test
require File.dirname(__FILE__) + '/../../cod2web'

Webrat.configure do |config| config.mode = :rack end

def puts msg
  puts
  puts msg
end

describe "App" do
  it "treba biti test" do
    app.environment.to_s.should == "test"
  end
  it "baza treba imati _test" do
    if not MongoMapper.database.name =~ /.*_test/
      exit
    end
  end
end

describe "web" do

  before :all do
    @mmusr = MmUser
  end

  after :all do
    @mmusr.delete_all
  end

  it "user table should be empty" do
    @mmusr.all.should == []
  end

  it 'should be login forma' do
    visit "/"
    @stdio_o = @stdio
    @stdio = nil
    response_body.should contain 'Login:'
    response_body.should contain 'Signup'
    @stdio = @stdio_o
  end

  it "should register" do
    visit '/signup'
    fill_in "user_name", :with => "Test user"
    fill_in "user_email", :with => "test@test.com"
    fill_in "user_password", :with => "test"
    fill_in "user_password_confirmation", :with => "test"
    click_button "Create account"

    # response.url should == '/'

    @mmusr.count.should == 1
  end

  it "flash should not be empty" do
    app.flash[:notice].should_not be_empty
  end

  it "should show login after registration" do
    
  end

  it "should be unregistered" do
    post '/', :user_email=>'', :user_password => ''
  end

end

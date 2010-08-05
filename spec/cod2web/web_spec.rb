require File.dirname(__FILE__) + '/../spec_helper'
require "sinatra"
Sinatra::Application.set :environment, :test
require File.dirname(__FILE__) + '/../../cod2web'

Webrat.configure do |config|
  config.mode = :rack
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

module LoginHelper
  def login_as_user
    fill_in "user_email", :with => "test@test.com"
    fill_in "user_password", :with => "test"
    click_button "login"
    within 'div#footer' do |s|
      s.should contain 'Running servers: 0'
    end
  end
end

describe "web" do

  before :all do
    MmUser.delete_all
    Coduser.delete_all
    Server.delete_all
    Srvinfo.delete_all
    Statistic.delete_all
  end

  after :all do
    MmUser.delete_all
    Coduser.delete_all
    Server.delete_all
    Srvinfo.delete_all
    Statistic.delete_all
  end

  context "opcenito" do
    it "user table should be empty" do
      MmUser.all.should == []
    end

    it 'should be login forma' do
      visit "/"
      response_body.should contain 'Login:'
      response_body.should contain 'Email'
      response_body.should contain 'Password'
      response_body.should contain 'Signup'
    end

    it "should not login" do
      pending "dodati p.error na login formu, on wrong passw."
      visit '/signup'
      fill_in "user_email", :with => "test@test.com"
      fill_in "user_password", :with => "test"
      response_body.should contain "Wrong username/password"
    end
  end

  context "Registration" do
    it "signup" do
      visit '/signup'
      fill_in "user_name", :with => "Test user"
      fill_in "user_email", :with => "test@test.com"
      fill_in "user_password", :with => "test"
      fill_in "user_password_confirmation", :with => "test"
      click_button "Create account"
      response_body.should contain "Servers"
      response_body.should contain "There are currently no servers managed by you."
    end

    it "count treba biti 1" do
      MmUser.count.should == 1
    end

    it "permission_level treba biti 1" do
      MmUser.find_by_email("test@test.com").permission_level.should == 1
    end

    it "flash should not be empty" do
      pending "testirati flash[]" # flash[:notice].should_not be_empty
    end

    it "should show login after registration" do
      pending
    end

    it "should not register again s istim podatcima" do
      pending "dodati uniq na user.email"
      visit '/signup'
      fill_in "user_name", :with => "Test user"
      fill_in "user_email", :with => "test@test.com"
      fill_in "user_password", :with => "test"
      fill_in "user_password_confirmation", :with => "test"
      click_button "Create account"
      response_body.should contain "This username is no avaliable!"
    end

    after :all do
      MmUser.delete_all
    end
  end

  context "Guest" do
    after :all do
      MmUser.delete_all
    end

    it "pocetna" do
      visit '/'
      within 'div#content' do |scope|
        scope.should have_selector("div#sinatra_authentication_flash")
      end
      within 'div#navbar' do |scope|
        scope.should_not contain /\w+/
      end
      within 'div#footer' do |scope|
        scope.should contain /OS: (\w+)/
        scope.should contain /Ruby: (\w+)/
        scope.should contain /Sinatra: (\w+)/
        scope.should contain "CoD2: 1.3"
        scope.should_not contain /(\| )?Running( servers)/
      end
    end

    it "register" do
      visit '/signup'
      fill_in "user_name", :with => "Test user"
      fill_in "user_email", :with => "test@test.com"
      fill_in "user_password", :with => "test"
      fill_in "user_password_confirmation", :with => "test"
      click_button "Create account"
    end

    include LoginHelper

    it "login" do
      visit '/'
      response_body.should_not contain "Servers"
      login_as_user
    end

    it "create new server" do
      visit '/'
      login_as_user
      # click_link "New server" # TODO: JS
      visit '/servers/new'
      fill_in "name", :with => "testsrv"
      fill_in "longname", :with => "Test server"
      uncheck 'enabled'
      select '28962'
      click_button 'Create!'
      # response_body.should contain "Server 'testsrv' is created!"
      # FIXME: template, flash, CSS za flash, image
    end

  end

  describe "Admin" do
    before :all do
      @user = MmUser.create! :name => "Test user", :email => "test@test.com", :password => "test", :password_confirmation => "test"
      @user.should be_valid
      @user.set :permission_level => -1
    end

    it "login as admin" do
      visit '/'
      response_body.should_not contain "Servers"
      fill_in "user_email", :with => "test@test.com"
      fill_in "user_password", :with => "test"
      click_button "login"
      within 'div#footer' do |s|
        s.should contain 'Running servers: 0'
      end
    end
  end

  after :all do
    MmUser.delete_all
  end

end

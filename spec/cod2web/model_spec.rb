require File.dirname(__FILE__) + '/../spec_helper'
require "sinatra"
Sinatra::Application.set :environment, :test
require File.dirname(__FILE__) + '/../../cod2web'

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

describe 'Models' do
  describe "MM baza" do
    before do
      @db = MongoMapper.database
      @conn = MongoMapper.connection
      @usr = Coduser
      @srv = Server
      @srvinfo = Srvinfo
      @stat = Statistic
    end

    context "DB" do
      it "type" do
        @db.class.should == Mongo::DB
        @conn.class.should == Mongo::Connection
      end

      it "host" do
        @conn.host.should == 'localhost'
      end

      it "name" do
        @db.name.should match /.*_test/
      end
    end

    shared_examples_for "mm tables" do
      it "prazan" do
        @t.all.should be_empty
      end

      it "type" do
        @t.class.should == Class
      end

      after :all do
        @t.delete_all
      end
    end

    describe Coduser do
      before :all do
        @t = Coduser
      end

      it_should_behave_like "mm tables"

      it "should have keys" do
        @user = @t.new
        @user.should respond_to :name
        @user.should respond_to :username
        @user.should respond_to :password
        @user.should respond_to :email
      end

      context "validacija" do
        before :all do
          @user = @t.new
        end

        it "empty email" do
          @user.save.should be_false
        end

        context "email-a" do
          it "bez domene" do
            @user.email = "test"
            @user.should_not be_valid
          end
          it "s krivom domenom" do
            @user.email = "test@test"
            @user.should_not be_valid
          end
          it "ispravni" do
            @user.email = "test@test.com"
            @user.should be_valid
          end
        end

        after :all do
          @user.delete
        end
      end

      context "many (children)" do
        before :all do
          @user = @t.create :name => "Test user", :username => "test", :password => nil, :email => "test@test.com"
        end

        after :all do
          @user.delete
        end

        context "servers" do
          it "should be empty" do
            @user.servers.should == []
          end

          context "should not create server" do
            before(:each) do
              @user_srv = @user.servers.create
            end
            it "prazan" do
              @user_srv.save.should be_false
            end
            it "sa name" do
              @user_srv.name = "test1"
              @user_srv.save.should be_false
            end
            after :each do
              @user_srv.delete
            end
          end

          context "should create server" do
            before :all do
              @user_srv = @user.servers.create
            end
            after :all do
              @user_srv.delete
            end
            it "dodaj name" do
              @user_srv.name = "test 1"
              @user_srv.should_not be_valid
            end
            it "dodaj longname" do
              @user_srv.longname = "Test server 1"
              @user_srv.should_not be_valid
            end
            it "dodaj enabled" do
              @user_srv.enabled = 0
              @user_srv.should be_valid
            end
          end
        end

        context "status" do
          before :each do
            @user_srv = @user.servers.create :name => "test1", :longname => "Test server 1"
          end
          it "when 0" do
            @user_srv.enabled = 0
            @user_srv.status.should == "off"
          end
          it "when 1" do
            @user_srv.enabled = 1
            @user_srv.status.should == "on"
          end
          it "when -1" do
            @user_srv.enabled = -1
            @user_srv.status.should == "unknown"
          end
          it "real_status" do
            @user_srv.real_status.should be_false
          end
          after :each do
            @user_srv.delete
          end
        end

      end
    end
  end
end

describe MmUser, "auth baza" do
  it "treba biti prazna" do
    MmUser.all.should == []
  end

  before :each do
    @mmusr = MmUser.new
  end

  context "validacija" do
    it "should not be valid na pocetku" do
      @mmusr.should_not be_valid
    end
    it "should have perms 1" do
      @mmusr.permission_level.should == 1
    end
    it "invalid" do
      @mmusr.name = "Test user"
      @mmusr.should_not be_valid
    end
  end

  after :all do
    @mmusr.delete
    MmUser.delete_all
  end

end

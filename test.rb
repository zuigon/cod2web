require "rubygems"
require "sinatra"
# require 'data_mapper'
require "dm-core"
require 'dm-migrations'
require 'rack-flash'
require "sinatra-authentication"
require "erb"
# require "haml"
require 'digest/md5'

set :app_file, __FILE__
set :root, File.dirname( __FILE__ )
# set :public, File.dirname( __FILE__ ) + '/public' 
use Rack::Static, :urls => ["/css", "/images", "/js"], :root => "public"
use Rack::Session::Cookie, :secret => 'hstuw nent ywet nywfn hatoh arst ywftyh'
use Rack::Flash

set :sinatra_authentication_view_path, Pathname(__FILE__).dirname.expand_path + "auth_views/"

set :views, File.dirname(__FILE__) + '/views'

# class DmUser
#   property :name, String
#   property :enabled, Boolean, :default => true
# end

DataMapper::setup(:default, {
  :adapter  => 'mysql',
  :host     => '192.168.1.250',
  :username => 'root',
  :password => 'bkrsta',
  :database => 'cod2web_dev'
})

# class User
#   include DataMapper::Resource
# 
#   property :id,         Serial
#   property :uname,      String
#   property :passw,      String
#   property :is_admin,   Boolean
#   property :enabled,    Boolean
#   # property :last_login, DateTime
# 
#   validates_presence_of :uname
#   validates_presence_of :passw
# 
#   def check
#     
#   end
# end

# DataMapper.auto_migrate!

# def auth?
#   !request.cookies["uname"].nil? and !request.cookies["passw"].nil? and !request.cookies["authed"].nil? and request.cookies["authed"].to_i == 1
# end
# 
# def admin?
#   
# end

def site_title
  "cod2web"
end

# layout :layout

helpers do
  def partial(name, options = {})
    item_name = name.to_sym
    counter_name = "#{name}_counter".to_sym
    if collection = options.delete(:collection)
      collection.enum_for(:each_with_index).collect do |item, index|
        partial(name, options.merge(:locals => { item_name => item, counter_name => index + 1 }))
      end.join
    elsif object = options.delete(:object)
      partial name, options.merge(:locals => {item_name => object, counter_name => nil})
    else
      haml "_#{name}".to_sym, options.merge(:layout => false)
    end
  end
end

get '/' do
  login_required
	haml :index
end

get '/test' do
  status 404
end

# get '/user/add' do
#   @user = User.create(:uname => params[:username], :passw => (Digest::MD5.hexdigest(params[:password])).to_s, :is_admin => 0, :enabled => 1)
# end

get '/status' do
  haml :status
  # "Loggedin var in cookie: #{request.cookies['authed']}"
end

# TODO: XML list of running servers
get '/servers.xml' do
  builder(:layout => false) do |xml|
    xml.instruct! :xml, :version => '1.0'
    xml.servers do
      xml.info "XML lista cod2 servera"
      # xml.title "cod2web xml"
      # xml.description "Liftoff to Space Exploration."
      # xml.link "http://liftoff.msfc.nasa.gov/"
      
      # @servers.each do |srv|
      #   xml.item do
      #     xml.name srv.name
      #     xml.run_as srv.run_as
      #     xml.owner srv.owner
      #     xml.created_at Time.parse(srv.created_at.to_s).rfc822()
      #     xml.stats do
      #       xml.players srv.players
      #     end
      #   end
      # end
    end
  end
end


__END__

@@layout
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"\>
%html{:xmlns => "http://www.w3.org/1999/xhtml"}
  %head
    %meta{:content => "text/html; charset=iso-8859-1", "http-equiv" => "Content-Type"}/
    %title= site_title
    %link{:href => "./css/main.css", :rel => "stylesheet", :type => "text/css"}/
    %link{:href => "./css/style.css", :rel => "stylesheet", :type => "text/css"}/
    %script{:src => "./js/main.js", :type => "text/javascript"}
  %body
    %div{:align => "center"}
      #container
        %div{:align => "left"}
          #headerimg
            #header2
              .title3
                = site_title
          #navagain
            #navbar
              - if current_user.email
                = partial("navbar")
          #stuff
            #content
              :css
                img * { border: 0px; background-color: #FFFFFF; text-decoration: none; }
              = yield
          #footer
            %div{:align => "center"}
              OS: #{`uname`.chop} | Ruby: #{RUBY_VERSION} | Sinatra: #{Sinatra::VERSION} | CoD2: 1.3 | Running servers: #{"0"}

@@index
%form{:action => "/login", :method => "post", :name => "form1"}
  %div{:align => "center", :style => "font-family: 'Segoe UI', 'Verdana';"}
    %br/
    Login on: cod2web
    %br/
    %table{:border => "0", :cellpadding => "3", :cellspacing => "3", :width => "250"}
      %tr
        %td{:width => "136"} Username:
        %td{:width => "138"}
          %input#username{:name => "username", :type => "text"}/
      %tr
        %td{:width => "136"} Password:
        %td{:width => "138"}
          %input#password{:name => "password", :type => "password"}/
      %tr
        %td  
        %td  
      %tr
        %td{:align => "center", :colspan => "2"}
          %input#btnlogin{:name => "btnlogin", :type => "submit", :value => "Login"}/

@@status
- if current_user.email
  = "Logged in, #{current_user.email}"
- else
  = "Not logged in ..."
  %a{:href=>"/"}
    Login

@@_navbar
%a{:href => "/"}
  Home
- if current_user.admin?
  %a{:href => "/servers"}
    Server log
%a{:href => "/srvlog"}
  Server log
%a{:href => "/files"}
  File Manager
%a{:href => "/config"}
  Server Config Editor
%a{:href => "/stats"}
  Server Stats
%a{:href => "/rcon"}
  RCON
%a{:href => "/logout"}
  Logout


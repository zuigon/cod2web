require "rubygems"
gem "activesupport", "= 2.3.8"
require "sinatra"
# require 'data_mapper'
gem "haml", "= 3.0.15"
require "dm-core"
require 'dm-migrations'
require "dm-mysql-adapter"
require 'rack-flash'
require "sinatra-authentication"
# require "erb"
require 'digest/md5'
require "mongo_mapper"
require 'sinatra_more/markup_plugin'
require "sinatra/reloader" if development?


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

MongoMapper.connection = Mongo::Connection.new('localhost')
MongoMapper.database = 'cod2web_dev'

require "models"

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

  def site_title() "cod2web" end

  def running_os
    raw = `uname`.chop
    if raw =~ /Darwin/
      return "Mac OS X"
    end
    return raw
  end

  def loggedin?
    !!current_user.email
  end

    # c = request.cookies["manage_server"]
    # c ||= "NONE"
    # response.set_cookie("manage_server", c)

  def manage_server
    # request.cookies["manage_server"].to_s
    request.cookies["manage_server"]
  end
  def managing?
    !request.cookies["manage_server"].nil? && request.cookies["manage_server"] != "NONE" && !request.cookies["manage_server"].empty?
  end
end

get '/' do
  login_required
  # haml :index
  # TODO: Home == Dashboard sa stats, srvs, news, ...
  redirect '/servers'
end

get '/test' do
  status 404
end

get '/servers' do
  login_required
  @servers = [
    {"name"=>"srv1",  "owner"=>"bkrsta", "status"=>0,  "size"=>20},
    {"name"=>"test1", "owner"=>"john",   "status"=>1,  "size"=>20},
    {"name"=>"test2", "owner"=>"steve",  "status"=>1,  "size"=>16},
    {"name"=>"test3", "owner"=>"bkrsta", "status"=>0,  "size"=>16},
    {"name"=>"test4", "owner"=>"bkrsta", "status"=>-1, "size"=>32}
  ]
  # filder servers (status)
  @servers.collect! do |s|
    s["status"] = case s["status"]
    when 0: "off"
    when 1: "on"
    when -1: "unknown"
    else "err"
    end; s
  end


  haml <<EOS
- if managing?
  Managing:
  = manage_server
- else
  Not managing ...
  = manage_server
  = request.cookies["manage_server"]

/ %ul{:id => 'server_list'}
/   %li{:class => 'on'}
/     item 1
/     %ul
/       %li
/         owner: bkrsta
/       %li
/         status: off
/       %li
/         size: 20
/       %li{:class => 'btns'}
/   %li{:class => 'off'}
/     item 2
/     %ul
/       %li
/         owner: max
/       %li
/         status: off
/       %li
/         size: 20
/       %li{:class => 'btns'}
/         / %input#btn_manage{:type=>'submit', :id=>'btn_manage', :value=>'Manage',  :class=>'btn'}
/         %a{:href=>'', :id=>'btn_manage', :value=>'Manage', :class=>'btn_a'} Manage
/   %li{:class => 'na'}
/     item 3
/     %ul
/       %li
/         owner: unknown
/       %li
/         status: off
/       %li
/         size: 20
/       %li{:class => 'btns'}
/         %a{:href=>'', :id=>'btn_manage', :value=>'Manage', :class=>'btn_a'} Manage
/         / %input#shell_textfield{:type=>'text', :class=>'sh_textbar', :size=>'70'}
/         / %input#btn_manage{:type=>'submit', :id=>'btn_manage', :value=>'Manage',  :class=>'btn'}

%ul#server_list
  - for srv in @servers
    = partial("server", :locals => {:srv=>srv})
EOS
end

get '/servers/sync' do
  login_required
  # 1. ispisi sve servere u hosting/ koji nisu u bazi
  #    za svaki novi srv:
  #      li narancaste boje, check pored svakog, btn import dolje
  # 2. pokazi one koji su obrisani, a u bazi su
  #    isto ...
end

get '/test2' do
  login_required
  response.set_cookie("test2", "test2")
  request.cookies["test2"]
end

# get '/manage/:owner-:name' do
get %r{/manage/([\w]+)-([\w]+)\.json} do |owner, name|
  # login_required
  # c = "#{owner}-#{name}"
  # response.set_cookie("manage_server", { :value => c,
  #   # :expires => 30.minutes.from_now,
  # })
  # request.cookies["manage_server"]

  layout false

  if !@servers.exist?
    return '{"status":"error"}'
  end
  if loggedin?
    if @user.owns_server(name)
      return '{"status":"ok"}'
    else
      return '{"status":"error"}'
    end
  else
    return '{"status":"not_logged_in"}'
  end

end

get '/servers/new' do
  login_required
  # forma za cr. srv-a
  # ime ne smije biti new ili sync
end

# get '/user/add' do
#   @user = User.create(:uname => params[:username], :passw => (Digest::MD5.hexdigest(params[:password])).to_s, :is_admin => 0, :enabled => 1)
# end

get '/status' do
  haml :status
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

# - textarea za logove
# echo "<br /><center><textarea name='logarea' id='logarea' cols='100' rows='30' readonly='readonly'>";
# echo ServerCore::ViewLog(SRV_LOG_FILENAME,"");
# echo "</textarea></center>";
# echo "<script language='Javasvcript'>logarea.scrollTop = logarea.scrollHeight</script>";

# - btns
# echo '<input name="shell_textfield" type="text" class="sh_textbar" size="70">';
# echo '<input name="shell_submit" type="submit" id="shell_submit" value="Execute" class="sh_submitbutton">';


__END__

@@layout
!!! Transitional
%html{:xmlns => "http://www.w3.org/1999/xhtml"}
  %head
    %meta{:content => "text/html; charset=iso-8859-1", "http-equiv" => "Content-Type"}/
    %title= site_title
    %link{:href => "/css/main.css", :rel => "stylesheet", :type => "text/css"}/
    %link{:href => "/css/style.css", :rel => "stylesheet", :type => "text/css"}/
    %script{:src => "http://ajax.googleapis.com/ajax/libs/jquery/1/jquery.min.js", :type => "text/javascript"}
    %script{:src => "http://plugins.jquery.com/files/jquery.cookie.js.txt", :type => "text/javascript"}
    %script{:src => "/js/main.js", :type => "text/javascript"}
  %body
    %div{:align => "center"}
      #container
        %div{:align => "left"}
          #headerimg
            #header2
              .title3= site_title
          #navagain
            #navbar
              - if loggedin?
                = partial("navbar_all")
              - if managing?
                = partial("navbar_manage")
              - if loggedin?
                %a{:href => "/logout"}
                  Logout
          #stuff
            #content
              :css
                img * { border: 0px; background-color: #FFFFFF; text-decoration: none; }
              = yield
          #footer
            %div{:align => "center"}
              OS: #{running_os} | Ruby: #{RUBY_VERSION} | Sinatra: #{Sinatra::VERSION} | CoD2: 1.3 | Running servers: #{"0"}

@@login_old
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
- if loggedin?
  = "Logged in, #{current_user.email}"
  %p= manage_server
  %p= request.cookies["manage_server"]
- else
  = "Not logged in ..."
  %a{:href=>"/"}
    Login
%ul
  - response.set_cookie("manage_server", "bkrsta-srv1")
  - for c in request.cookies
    %li
      %p= c[0]
      %p= c[1]

@@_navbar_all
%a{:href => "/"}
  Home (servers)
- if current_user.admin?
  /

@@_navbar_manage
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

@@_server
/ %li{:class => srv['status']}
- ovajm = manage_server=="#{srv['owner']}-#{srv['name']}"
%li{:class => srv['status'] + (ovajm ? " managed" : "")}
  = srv['name']
  %ul
    %li= "owner: " + srv['owner'].to_s
    %li
      = "status: #{srv['status']}"
    %li
      = "size: #{srv['size']}"
    %li{:class => 'btns'}
      / %a{:href=>"/manage/#{srv['owner']}-#{srv['name']}", :id=>'btn_manage', :value=>'Manage', :class=>'btn_a'} Manage
      - if ovajm
        %a{:href=>"#", :onclick => "manage('none')", :id=>'btn_manage', :value=>'Close', :class=>'btn_a'} Close
      - else
        %a{:href=>"#", :onclick => "manage('#{srv['owner']}-#{srv['name']}')", :id=>'btn_manage', :value=>'Manage', :class=>'btn_a'} Manage

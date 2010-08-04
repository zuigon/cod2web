require "rubygems"
gem "activesupport", "= 2.3.8"
require "sinatra"
gem "haml", "= 3.0.15"
# require "dm-core"
# require 'dm-migrations'
# require "dm-mysql-adapter"
require "mongo_mapper"
require 'digest/md5'
require 'digest/sha1'
require 'rack-flash'
require "models"
require "sinatra-authentication"
# require 'sinatra_more/markup_plugin'
# require "sinatra/reloader" if development?

def hosting_dir
  "/Users/bkrsta/Projects/cod2man/hosting"
end

logger = Logger.new($stdout) # za sin-auth

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

# DataMapper::setup(:default, {
#   :adapter  => 'mysql',
#   :host     => '192.168.1.250',
#   :username => 'root',
#   :password => 'bkrsta',
#   :database => 'cod2web_dev'
# })

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

  def admin?()
    if !current_user.nil?
      return current_user.admin?
    end
    false
  end
  def manage_server() request.cookies["manage_server"] end
  def managing?()
    !request.cookies["manage_server"].nil? && request.cookies["manage_server"] != "NONE" && !request.cookies["manage_server"].empty?
  end
  def link_to(text, url)
    "<a href='#{url}'>#{text}</a>"
  end
  def login_required
    if current_user.class != GuestUser and !current_user.nil?;
      return true
    else
      session[:return_to] = request.fullpath
      session[:show_login] = true
      redirect '/login'
      return false
    end
  end
  def running_servers
    x=Server.count(:enabled=>1); "#{x} (enabled)"
    # ((!x.nil?) ? x : 0 ).to_s + " (enabled)"
  end
  def bm(text, &block)
    b = Time.now
    yield block
    puts "[#{text}] #{Time.now-b} sec."
  end
  def valid_name?(name)
    !%w(new list sync add).include? name and name.length >= 3 and name =~ /[a-zA-Z0-9_]/
  end
end

get '/' do
  login_required
  # haml :index
  # TODO: Home == Dashboard sa stats, srvs, news, ...
  redirect '/servers'
end

get '/test' do
  "test ..."
end

get '/servers' do
  login_required
  # X @servers = [{"name"=>"srv1",  "owner"=>"bkrsta", "status"=>0,  "size"=>20}]
  @user = Coduser.find_by_email current_user.email

  if admin?
    servers = Server.all
  else
    servers = @user.servers.all
  end

  @servers = []
  servers.each do |s|
    n = {}
    beginning = Time.now
    output = `cd #{hosting_dir} && ./control #{@user.username}-#{s.name} status`
    puts "[/servers, get server status, #{s.name}] output: #{Time.now - beginning} sec."
    n["enabled"] = if output =~ /is not running/; 0
    elsif output =~ /is running/; 1
    else -1
    end
    # name, longname, owner, enabled, size, port
    n["longname"] = s.longname
    n["name"] = s.name
    n["owner"] = s.coduser.username
    n["status"] = s.status n["enabled"] # func u modelu
    # n["enabled"] = s.enabled
    n["size"] = s.srvinfo.size
    n["port"] = s.srvinfo.port
    @servers << n
  end

  haml :servers
end

get '/servers/sync' do
  login_required
  # 1. ispisi sve servere u hosting/ koji nisu u bazi
  #    za svaki novi srv:
  #      li narancaste boje, check pored svakog, btn import dolje
  # 2. pokazi one koji su obrisani, a u bazi su
  #    isto ...

  # require "fileutils"

  servers = Server.all
  @servers_disk = []

  @servers_db = []
  servers.each do |s|
    @servers_db << ["#{s.coduser.username}-#{s.name}", s.longname]
  end

  Dir["#{hosting_dir}/*-*"].each do |d|
    d = d.gsub /.*\//, ''
    if File.exist? "#{hosting_dir}/#{d}/.cod2server"
      @servers_disk << [d, `cd #{hosting_dir}/#{d}/ && grep SERVER_NAME vars.txt | sed 's:.*=::g' | sed "s:'::g"`]
    end
    # output = `cd #{hosting_dir} && ./control #{@user.username}-#{s.name} status`
  end

  haml :servers_sync
end

get %r{/manage/([\w]+)-([\w]+)\.json} do |owner, name|
  # login_required
  # TODO: /manage .json
  layout false
  if !@servers.exist?
    return '{"status":"error"}'
  end
  if logged_in?
    if @user.owns_server(name)
      return '{"status":"ok"}'
    else
      return '{"status":"error"}'
    end
  else
    return '{"status":"not_logged_in"}'
  end
end

get %r{/servers/start/([\w]+)-([\w]+)} do |owner, name|
  # user = Coduser.find_by_email current_user.email
  user = Coduser.find_by_username owner
  server = user.servers.find_by_name name

  @output = `cd #{hosting_dir} && ./control #{owner}-#{name} start`

  if @output =~ /has started/ # started
    flash[:notice] = "Server is started"
    server.enabled = 1
  elsif @output =~ /already running/ # already running
    flash[:error] = "Server is already running!"
    server.enabled = 1
  else
    flash[:error] = "Unknown error!"
    server.enabled = -1
  end

  redirect '/servers'
end

get %r{/servers/stop/([\w]+)-([\w]+)} do |owner, name|
  user = Coduser.find_by_username owner
  server = user.servers.find_by_name name

  @output = `cd #{hosting_dir} && ./control #{owner}-#{name} stop`

  if @output =~ /Stop COD2 server/ # started
    flash[:notice] = "Server is stopped"
    server.enabled = 0
  elsif @output =~ /is not running/ # already running
    flash[:error] = "Server is not running!"
    server.enabled = 0
  else
    flash[:error] = "Unknown error!"
    server.enabled = -1
  end

  redirect '/servers'
end

get %r{/servers/restart/([\w]+)-([\w]+)} do |owner, name|
  user = Coduser.find_by_username owner
  server = user.servers.find_by_name name

  @output = `cd #{hosting_dir} && ./control #{owner}-#{name} restart`

  @output = @output.split("\n")
  @output = @output[1..@output.count].join "\n"

  if @output =~ /has started with/
    flash[:notice] = "Server is restarted"
    server.enabled = 1
  elsif @output =~ /is not running/
    flash[:error] = "Server is not running!"
    server.enabled = 0
  else
    flash[:error] = "Unknown error!"
    server.enabled = -1
  end

  redirect '/servers'
end

get '/stats' do
  # grafovi, players
end

get '/servers/new' do
  login_required
  # forma za cr. srv-a
  # ime ne smije biti new ili sync

  @owners = Coduser.all.collect {|x| x.name }
  @data = {"name"=>"newsrv1", "longname"=>"New srv 1", "owner"=>"bkrsta", "ports"=>[28962,28963,28964,28965,28966]}
  haml :new_srv
end

post '/servers/new' do

  name, longname, enabled, owner, port = params[:name], params[:longname], params[:enabled], params[:owner], params[:port]

  user = Coduser.find_by_username owner

  if !name.empty? and !longname.empty? and !owner.empty? and valid_name? name
    server = Server.create :name => name, :longname => longname, :enabled => (enabled)?1:0
    server.coduser = Coduser.find_by_username owner
    server.coduser.save

    tmpfile = ("#{hosting_dir}/tmp/temp_input")
    tmpfile = nil if tmpfile.start_with? "/tmp/"
    File.open(tmpfile, 'w'){|f|
      f.puts "" # run as user (unix)
      f.puts "#{user.name}" # server admin name
      f.puts "nospam_#{user.email}" # admin email
      f.puts longname # server name
      f.puts port
      f.puts "" # generated RCON pw
      f.puts "" # max players
    }

    output = `cd #{hosting_dir} && ruby create.rb -o #{owner} -n #{name} < #{tmpfile}`

    server.save

    flash[:notice] = "Server created!"
    haml "%p.error= flash[:notice]"
  else
    @owners = Coduser.all.collect {|x| x.name }
    @data = {"name"=>params[:name], "longname"=>params[:longname], "owner"=>params[:owner]}
    haml :new_srv
  end
end

get '/status' do
  haml :status
end

# TODO: XML list of running servers
get '/servers.xml' do
  if current_user.admin?
    servers = Server.all
  else
    user = Coduser.find_by_email current_user.email
  end

  servers ||= user.servers.all

  builder(:layout => false) do |xml|
    xml.instruct! :xml, :version => '1.0'
    xml.owner user.username
    xml.servers do

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
              - if logged_in?
                = partial "navbar_all"
              - if admin?
                = partial "navbar_admin"
              - if managing?
                - if admin?
                  = partial "navbar_admin_manage"
                = partial "navbar_manage"
              - if logged_in?
                %a{:href => "/logout"}
                  Logout
          #stuff
            #content
              :css
                img * { border: 0px; background-color: #FFFFFF; text-decoration: none; }
              = yield
          #footer
            = partial "footer"

@@_footer
%div{:align => "center"}
  OS: #{running_os} | Ruby: #{RUBY_VERSION} | Sinatra: #{Sinatra::VERSION} | CoD2: 1.3 | Running servers: #{running_servers}

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
- if logged_in?
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

@@_navbar_admin
%a{:href => '/servers/sync', :alt => "Sinkroniziranje pravih servera s bazom"}
  +Sync servers

@@_navbar_admin_manage

@@_navbar_manage
%a{:href => "/srvlog"}
  Server log
%a{:href => "/mods"}
  Mods (upload)
%a{:href => "/config"}
  Server Config Editor
%a{:href => "/stats"}
  Server Stats
%a{:href => "/rcon"}
  RCON

@@servers
- if flash[:error]
  %p.notice= flash[:error]
- if flash[:notice]
  %p.notice= flash[:notice]
%ul#server_list
  - for srv in @servers
    = partial("server", :locals => {:srv=>srv})
%a{:href=>"/servers/new", :onclick => "srv_novi()", :id=>'btn_novi_srv', :class=>'button'} New server

@@_server
/ %li{:class => srv['status']}
- ovajm = manage_server=="#{srv['owner']}-#{srv['name']}"
%li{:class => srv['status'] + (ovajm ? " managed" : "")}
  %ul
    %div.name
      = srv['longname']
    %ul.info
      - if admin? or 1
        %li= "owner: " + link_to(srv['owner'], "/users/"+srv['owner'].to_s)
      %li
        = "shortname: #{srv['name']}"
      %li
        = "status: #{srv['status']}"
      %li
        = "size: #{srv['size']}"
    %div{:class => 'btns'}
      - if ovajm
        - if srv['enabled'] == 1
          / %a{:href=>"#", :onclick => "srv_stop('#{srv["shortname"]}')", :id=>'btn_manage', :class=>'button'} Stop
          %a{:href=>"/servers/stop", :id=>'btn_manage', :class=>'button'} Stop
          / %a{:href=>"#", :onclick => "srv_restart('#{srv["shortname"]}')", :id=>'btn_manage', :class=>'button'} Restart
          %a{:href=>"/servers/restart", :id=>'btn_manage', :class=>'button'} Restart
        - if srv['enabled'] == 0
          / %a{:href=>"#", :onclick => "srv_start('#{srv["shortname"]}')", :id=>'btn_manage', :class=>'button'} Start
          %a{:href=>"/servers/restart", :id=>'btn_manage', :class=>'button'} Start
        %a{:href=>"#", :onclick => "srv_manage('none')", :id=>'btn_manage', :class=>'button'} Close
      - else
        %a{:href=>"#", :onclick => "srv_manage('#{srv['owner']}-#{srv['name']}')", :id=>'btn_manage', :class=>'button'} Manage

@@servers_sync
%form(action='/servers/sync' method='POST')
  %ul.servers_sync
    %p
      %h2 DB servers:
    - for s in @servers_db
      %li
        = s[0]
        %b= s[1]
    %p
      %h2 disk servers:
    - for s in @servers_disk
      %li
        = s[0]
        %b= s[1]
    - za_db = @servers_disk - @servers_db
    - if za_db != []
      %p
        %h2 U bazi nedostaju:
        - for s in za_db
          %li
            %input(type='checkbox' name="to_db" value=s checked='yes')
            = s[0]
            %b= s[1]
    - del_db = @servers_db - @servers_disk
    - if !del_db.empty?
      %h2 Za obrisati iz baze:
      - for s in del_in_db
        %li
          %input(type='checkbox' name="del_db" value=s checked='no')
          = s[0]
          %b= s[1]
    %input(type='submit' name="btn_sync" value='Sync!' class='button')

@@new_srv
%form(action='/servers/new' method='POST')
  :css
    ul.new_srv li p.input { left: 100px; }
  %ul.new_srv
    %li
      Name:
      %p.input
        %input{"type"=>'text', "name"=>"name", "value"=>@data['name']}
    %li
      Longname:
      %p.input
        %input{"type"=>'text', "name"=>"longname", "value"=>@data['longname']}
    %li
      Enabled:
      %p.input
        %input{"type"=>'checkbox', "name"=>"enabled", "value"=>'enabled', "checked"=>'no'}
    %li
      Owner:
      %p.input
        %select{:name => "owner"}
          - for owner in @owners
            %option{ :selected => owner == @data['owner']}= owner
    %li
      Port:
      %p.input
        %select{:name => "port"}
          - for port in @data['ports']
            %option= port
    %li
      %input(type='submit' name="btn_create" value='Create!')

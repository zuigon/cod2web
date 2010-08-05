def bm(text, &block) b = Time.now; yield block; puts "[#{text}] #{Time.now-b} sec."; end

require "rubygems"
gem "activesupport", "= 2.3.8"
gem "haml", "= 3.0.15"
# require "dm-core"
# require 'dm-migrations'
# require "dm-mysql-adapter"
%w(sinatra sinatra/config_file mongo_mapper digest/md5 digest/sha1 rack-flash sinatra-authentication memcache).each do |r|
  # bm r do
  require r
  # end
end
# require 'sinatra_more/markup_plugin'
configure :development do
  require "sinatra/reloader"
  # register Sinatra::Reloader
end

configure do
  @config = YAML::load(File.read('config/config.yml'))[Sinatra::Application.environment.to_s]

  @db_host = @config["database"]["host"]
  @db_name = @config["database"]["name"]

  @mc_host = @config["memcached"]["host"]
  @mc_port = @config["memcached"]["port"] || '11211'

  set :app_file, __FILE__
  set :root, File.dirname( __FILE__ )
  # set :public, File.dirname( __FILE__ ) + '/public' 
  use Rack::Static, :urls => ["/css", "/images", "/js"], :root => "public"
  use Rack::Session::Cookie, :secret => 'hstuw nent ywet nywfn hatoh arst ywftyh'
  use Rack::Flash

  set :sinatra_authentication_view_path, Pathname(__FILE__).dirname.expand_path + "auth_views/"
  set :views, File.dirname(__FILE__) + '/views'
end

require "models"

def hosting_dir() "/Users/bkrsta/Projects/cod2man/hosting" end

C = MemCache.new "#{@mc_host}:#{@mc_port}"

logger = Logger.new($stdout) # za sin-auth

class S
  # helper za servere (prave)

  def self.start s
    (File.directory? "#{hosting_dir}/#{s}") ? `cd #{hosting_dir} && ./control #{s} start` : false
  end

  def self.stop s
    (File.directory? "#{hosting_dir}/#{s}") ? `cd #{hosting_dir} && ./control #{s} stop` : false
  end

  def self.restart s
    (File.directory? "#{hosting_dir}/#{s}") ? `cd #{hosting_dir} && ./control #{s} restart` : false
  end

  def self.status s
    (File.directory? "#{hosting_dir}/#{s}") ? `cd #{hosting_dir} && ./control #{s} status` : false
  end

  def self.no_running user
    
  end

end

# layout :layout

before do
  if logged_in?
    @user = Coduser.find_by_email current_user.email
    if @user.nil?
      # halt 404, "Trenutni user nije u Coduser"
      puts " Trenutni User nije u Coduser!"
      c = current_user
      user = Coduser.new :username=>c.email.split('@')[0], :name=>c.name, :email=>c.email
      user.save
      puts " dodao sam ga u Coduser -- #{user.username}, #{user.name}, #{user.email}"
    end
  end
end

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
  def site_title()
    "cod2web"
  end
  def running_os
    raw = `uname`.chop
    if raw =~ /Darwin/
      return "Mac OS X"
    end
    return raw
  end
  def admin?()
    !current_user.nil? && current_user.admin?
  end
  def manage_server()
    request.cookies["manage_server"]
  end
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
    if admin?
      x=Server.count(:enabled=>1) || 0
    else
      x=@user.servers.count(:enabled=>1) || 0
    end
    "#{x}"
  end
  def valid_name?(name)
    !%w(new list sync add del).include? name and name.length >= 3 and name =~ /[a-zA-Z0-9_]/
  end
  def reqadmin
    login_required
    if !admin?
      halt 404, haml(:error404, :layout=>false)
    end
  end
end

get '/' do
  login_required
  # haml :index
  # TODO: Home: Dashboard sa stats, srvs, news, ...
  redirect '/servers'
end

get '/test' do
  "test ..."
end

get '/servers' do
  login_required
  @user = Coduser.find_by_email current_user.email

  if admin?
    servers = Server.all
  else
    servers = @user.servers.all
  end

  @servers = []
  servers.each do |s|
    n = {}
    # beginning = Time.now
    output = S.status "#{@user.username}-#{s.name}"
    # puts "[/servers, get server status, #{s.name}] output: #{Time.now - beginning} sec."
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

post '/servers/sync' do
  reqadmin

  @to_db  = params[:to_db] || []
  @del_db = params[:del_db] || []

  deleted = 0

  # Del DB:
  @del_db.each do |s|
    # if name =~ /./ and owner =~ /./
      owner, name = s.split '-'
      server = Server.find_by_name name
      if !server.nil?
        if owner.empty?
          server.srvinfo.delete
          server.delete
        else
          server.delete if server.coduser.username == owner
        end
        deleted+=1
      end
    # end
  end
  flash[:notice] = "#{deleted} servers removed from DB!"
  redirect '/servers/sync'

  # Add to DB:
  # TODO: implem. /servers/sync add to db

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

  @output = S.start "#{owner}-#{name}"

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

  @output = S.start "#{owner}-#{name}"

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

  @output = S.restart "#{owner}-#{name}"

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

  @owners = Coduser.all.collect {|x| x.username }
  @data = {"name"=>"novisrv", "longname"=>"Novi Server", "owner"=>@user.username, "ports"=>[28962,28963,28964,28965,28966]}
  haml :new_srv
end

post '/servers/new' do

  name, longname, enabled, owner, port = params[:name], params[:longname], params[:enabled], params[:owner], params[:port]

  if !admin?
    owner = @user.username
  end

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

get %r{/servers/del/([\w]+)?-([\w]+)} do |owner, name|
  login_required

  @srv = Server.find_by_name name
  if @srv.nil?
    flash[:error] = "Error: server not exists! Or DB error..."
  else
    if @srv.coduser.email == current_user.email or admin?
      @srv.delete
      flash[:notice] = "Server '#{name}' deleted"
    else
      flash[:error] = "Error"
    end
  end
  redirect '/'
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

# @@layout
# 
# @@_footer
# 
# @@login_old
# 
# @@status
# 
# @@_navbar_all
# 
# @@_navbar_admin
# 
# @@_navbar_admin_manage
# 
# @@_navbar_manage
# 
# @@servers
# 
# @@_server
# 
# @@servers_sync
# 
# @@new_srv
# 
# @@error404

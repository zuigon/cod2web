MongoMapper.connection = Mongo::Connection.new('localhost')
MongoMapper.database = 'cod2web_dev'

class Coduser
  include MongoMapper::Document
  key :name,        String
  key :username,    String, :required => true
  key :password,    String, :required => true
  key :email,       String, :required => true
  timestamps!

  many :servers
end

class Server
  include MongoMapper::Document
  key :name,        String, :required => true # shortname, dirname
  key :longname,    String, :required => true
  key :enabled,     Integer, :required => true
  timestamps!

  belongs_to :coduser
  one :srvinfo

  def status(str=nil)
    case (str) ? str : self.enabled
    when 0: "off"
    when 1: "on"
    when -1: "unknown"
    else "err"
    end
  end
end

class Srvinfo
  include MongoMapper::Document
  key :runuser,     String
  key :admin,       String
  key :email,       String
  key :port,        Integer, :required => true
  key :rcon,        String
  key :size,        Integer, :required => true

  belongs_to :server
end

class Statistic
  include MongoMapper::Document
  key :time,        Time
  key :players,     Integer
  timestamps!

  belongs_to :server
end

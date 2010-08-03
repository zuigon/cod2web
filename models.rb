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
  key :enabled,     Boolean, :required => true
  timestamps!

  belongs_to :coduser
  one :srvinfo
end

class Srvinfo
  include MongoMapper::Document
  key :runuser,     String
  key :admin,       String
  key :email,       String
  key :port,        Integer, :required => true
  key :rcon,        String
  key :size,        Integer
  # key :maps, Array

  belongs_to :server
end

class Statistic
  include MongoMapper::Document
  key :time,        Time
  key :players,     Integer

  belongs_to :server
end

require "rubygems"
require "mongo_mapper"

MongoMapper.connection = Mongo::Connection.new('localhost')
MongoMapper.database = 'cod2web_dev'

require "./models"

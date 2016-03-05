class Place
  Mongo::Logger.logger.level = ::Logger::INFO

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client[:places]
  end

  def self.load_all(file)
    read = File.read(file)
    hash = JSON.parse(read)
    collection.insert_many(hash)
  end
end
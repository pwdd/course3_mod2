class Place
  Mongo::Logger.logger.level = ::Logger::INFO
  attr_accessor :id, :formatted_address, :location, :address_components

  def initialize(params={})
    @id = params[:_id].nil? ? params[:id] : params[:_id].to_s
    @formatted_address = params[:formatted_address] || nil
    @location = Point.new(params[:geometry][:geolocation]) || nil
    unless params[:address_components].nil?
      @address_components = params[:address_components].map do |component|
        AddressComponent.new(component)
      end
    else
      nil
    end
  end

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

  def self.find_by_short_name(short_name)
    collection.find(:'address_components.short_name' => short_name)
  end

  def self.to_places(view)
    return nil if view.nil?
    view.inject([]) { |memo, doc| memo << Place.new(doc) }
  end

  def self.find(id)
    doc = collection.find(_id: BSON::ObjectId.from_string(id)).first
    doc.nil? ? nil : Place.new(doc)
  end

  def self.all(offset=0, limit=nil)
    set = collection.find.skip(offset)
    set = limit.nil? ? set : set.limit(limit)
    set.map { |doc| Place.new(doc) }
  end

  def self.get_address_components(sort={}, offset=0, limit=nil)
    q = [{ :$unwind => '$address_components' },
         { :$project => { address_components: 1, 
                          formatted_address: 1, 
                          :'geometry.geolocation' => 1 } }
    ]
    q << { :$sort => sort } unless sort.size.zero?
    q << { :$skip => offset } unless offset.zero?
    q << { :$limit => limit } unless limit.nil?

    collection.find.aggregate(q)
  end

  def self.get_country_names
    q = [
      { :$project => { :'address_components.long_name' => 1, 
                       :'address_components.types' => 1 } },
      { :$unwind => '$address_components' },
      { :$match => { :'address_components.types' => 'country' } },
      { :$group => { _id: '$address_components.long_name' } }
    ]
    
    collection.find.aggregate(q).map { |doc| doc[:_id] }
  end

  def self.find_ids_by_country_code(country_code)
    q = [
      { :$match => { :'address_components.short_name' => country_code } },
      { :$project => { _id: 1 } }
    ]

    collection.find.aggregate(q).map { |doc| doc[:_id].to_s }
  end

  def self.create_indexes
    collection.indexes.create_one(:'geometry.geolocation' => Mongo::Index::GEO2DSPHERE)
  end

  def self.remove_indexes
    collection.indexes.drop_one('geometry.geolocation_2dsphere')
  end

  def self.near(point, max_meters=0)
    q = { :$near => point.to_hash }
    q[:$maxDistance] = max_meters unless max_meters.zero?
    
    collection.find(:'geometry.geolocation' => q)
  end

  def destroy
    self.class.collection.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end
end




























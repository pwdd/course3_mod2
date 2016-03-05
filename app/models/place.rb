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
end




























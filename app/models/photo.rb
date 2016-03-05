class Photo
  attr_accessor :id, :location, :contents

  def initialize(params={})
    @id = params[:_id].nil? ? params[:id] : params[:_id].to_s
    if params[:metadata] && params[:metadata][:location]
      if params[:metadata][:location].is_a?(Point)
        @location = params[:metadata][:location]
      else
        @location = Point.new(params[:metadata][:location])
      end
    end

    if params[:metadata] && params[:metadata][:place]
      @place = params[:metadata][:place]
    end
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.all(offset=0, limit=nil)
    docs = mongo_client.database.fs.find.skip(offset)
    docs = docs.limit(limit) unless limit.nil?
    docs.map { |doc| Photo.new(doc) }
  end

  def persisted?
    !@id.nil?
  end

  def save
    description = {}

    if persisted?
      description[:metadata] = { location: @location.to_hash }
      description[:metadata][:place] = @place
      self.class.mongo_client.database.fs
        .find(:_id=> BSON::ObjectId.from_string(@id))
        .update_one(description)
    else
      geolocation = EXIFR::JPEG.new(@contents).gps
      @location = Point.new({ lng: geolocation.longitude, lat: geolocation.latitude })
      description[:content_type] = 'image/jpeg'
      description[:metadata] = { location: @location.to_hash }
      description[:metadata][:place] = @place
      @contents.rewind
      gridfs = Mongo::Grid::File.new(@contents.read, description)
      id = self.class.mongo_client.database.fs.insert_one(gridfs)
      @id = id.to_s
    end
  end
end
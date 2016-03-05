class Photo
  attr_accessor :id, :location
  attr_writer :contents

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

  def self.find(id)
    doc = mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(id)).first
    doc.nil? ? nil : Photo.new(doc)
  end

  def self.find_photos_for_place(doc_id)
    mongo_client.database.fs.find('metadata.place' => BSON::ObjectId.from_string(doc_id))
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

  def contents
    gridfs = self.class.mongo_client.database.fs.find_one(_id: BSON::ObjectId.from_string(@id))
    if gridfs
      buffer = ''
      gridfs.chunks.each { |chunk| buffer.concat(chunk.data.data) }
    end
    buffer
  end

  def destroy
    self.class.mongo_client.database.fs.find(_id: BSON::ObjectId.from_string(@id)).delete_one
  end

  def find_nearest_place_id(max_meters)
    search = Place.near(@location, max_meters)
                  .limit(1)
                  .projection(_id: 1)
                  .first
    search[:_id] || 0
  end

  def place
    return nil if @place.nil?
    @place.is_a?(Place) ? Place.find(@place.id) : Place.find(@place.to_s)
  end

  def place=(place)
    if place.is_a?(Place)
      @place = BSON::ObjectId.from_string(place.id)
    elsif place.is_a?(String)
      @place = BSON::ObjectId.from_string(place)
    else
      @place = place
    end
  end
end
class Photo
  attr_accessor :id, :location, :contents

  def initialize(params)
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
end
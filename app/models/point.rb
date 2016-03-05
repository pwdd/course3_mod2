class Point
  attr_accessor :longitude, :latitude

  def initialize(params={})
    if params[:lng] && params[:lat]
      @longitude = params[:lng]
      @latitude = params[:lat]
    else
      @longitude, @latitude = params[:coordinates]
    end
  end

  def to_hash
    { type: 'Point', coordinates: [longitude, latitude] }
  end
end
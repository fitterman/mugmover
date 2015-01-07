class PhotosController < ApplicationController
  # GET /photos
  # GET /photos.json
  def index
    @photos = Flickr.get_photos(params[:flickr_id])
    @total_photos = @photos.total.to_i
  end

  # GET /photos/1
  # GET /photos/1.json
  def show
    @photo = Flickr.get_info(params[:flickr_id], params[:id])
  end

private

    # Only allow the white list through.
    def photo_params
      params.require(:photo).permit(:flickr_id, :provider, :unique_id)
    end
end

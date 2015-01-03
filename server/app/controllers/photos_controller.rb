class PhotosController < ApplicationController
  # GET /photos
  # GET /photos.json
  def index
    @photos = Flickr.get_photos(params[:flickr_id])
  end

  # GET /photos/1
  # GET /photos/1.json
  def show
    @photos = Flickr.get_photos(params[:flickr_id])
    @photo = Flickr.get_info(params[:flickr_id], params[:id])
  end

private

    # Never trust parameters from the scary internet, only allow the white list through.
    def photo_params
      params.require(:photo).permit(:flickr_id, :provider, :unique_id)
    end
end

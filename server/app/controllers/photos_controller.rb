class PhotosController < ApplicationController

  # GET photos.jpeg
  def show
    photo = Photo.find(params[:id])
    respond_to do |format|
      format.jpeg { send_data(Base64.decode64(photo.thumbnail), type: 'image/jpeg') }
    end
    return
  end

private

    # Only allow the white list through.
    def photo_params
      params.require(:photo).permit(:flickr_id, :provider, :unique_id)
    end
end

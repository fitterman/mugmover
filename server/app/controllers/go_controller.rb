class GoController < ApplicationController
  
  # GET /a/:a_id/photos(.:format)
  # This takes extra parameters to regulate where it gets the photos
  #   +i+ is the index of the photo to be sure to obtain
  #   +n+ is the number of photos to send back in one response
  # internally the photos come back in pages of PAGESIZE.
  def show
    @hsa = HostingServiceAccount.find(params[:id])
    @photos_per_request = params[:n]
    @photos = @hsa.photos.limit(@photos_per_request).offset(params[:i])
    @total_photos = @hsa.photos.count
  end

private

    # Only allow the white list through.
    def photo_params
      params.require(:photo).permit(:flickr_id, :provider, :unique_id)
    end
end

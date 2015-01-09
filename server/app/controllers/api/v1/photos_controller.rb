module Api
  module V1
    # TODO Get this back to using ApiController
    class PhotosController < ApplicationController
      # NOTE: If PAGESIZE is so small that it can't span a page with images, the
      # continuation code may leave a gap if images in the middle of the horizontal
      # scroller. Yes, it does handle getting more, but not well enough to handle
      # this one case.
      PAGESIZE = 50

      # GET /photos.json
      # This takes extra parameters to regulate where it gets the photos
      #   +n+ is the index of the photo to be sure to obtain
      # internally the photos come back in pages of PAGESIZE.
      def index
        @photos = Flickr.get_photos(params[:flickr_id], params[:n].to_i, PAGESIZE)
        @total_photos = @photos.total.to_i
        @photos_per_request = @photos.perpage.to_i
      end

      # GET /photos/1.json
      def show
        @photo = Flickr.get_info(params[:flickr_id], params[:id])
      end

    private
        # TODO Get back to using this...
        # Only allow the white list through.
        def photo_params
          params.require(:photo).permit(:flickr_id, :n, :id)
        end
    end
  end
end
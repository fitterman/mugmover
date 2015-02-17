module Api
  module V1
    # TODO Get this back to using ApiController
    class PicsController < ApplicationController
      skip_before_action :verify_authenticity_token

      PAGESIZE = 10

      # GET /photos.json
      # This takes extra parameters to regulate where it gets the photos
      #   +n+ is the index of the photo to be sure to obtain
      # internally the photos come back in pages of PAGESIZE.
      def index
        @hsa = HostingServiceAccount.find(params[:a_id])
        params[:n] ||= 0
        @index = Integer(params[:n]) * PAGESIZE
        @photos = @hsa.photos.limit(PAGESIZE).offset(@index)
        @total_photos = @hsa.photos.count
        @photos_per_request = PAGESIZE
      end

      # GET /photos/1.json
      def show
        @hsa = HostingServiceAccount.find(params[:a_id])
        @photo = @hsa.photos.includes(:faces).find(params[:id])
      end

      # GET /photos/1.json
      def details
        @hsa = HostingServiceAccount.find(params[:a_id])
        @photo = @hsa.photos.find(params[:id])
      end

      # Effectively, this can only be used to update the flag at the moment
      def update
        @hsa = HostingServiceAccount.find(params[:a_id])
        @photo = @hsa.photos.find(params[:id])
      end

      # Set the flag in the record
      def flag
        @hsa = HostingServiceAccount.find(params[:a_id])
        @photo = @hsa.photos.find(params[:id])
        @photo.flag = params[:flag]
        if @photo.save
          result = {status: 'ok', photo: {flag: @photo.flag}}
          render json: result 
        else
          result = {status: 'fail', errors: @photo.errors.full_messages}
          render json: result, status: :bad_request
        end

        @photo.update_column(:flag, params[:flag])
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
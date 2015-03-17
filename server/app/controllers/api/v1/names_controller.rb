module Api
  module V1
    class NamesController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :pre_validation

      # GET /names.json
      def index
      end

      # GET /names/id.json
      def show
        @faces = @named_face.faces.includes(:photo)
      end


    private

      def pre_validation
        params[:photo_id] ||= params[:photoId]
        params[:named_face_id] ||= params[:namedFaceId]
        @errors = []
        hsa_query = HostingServiceAccount.where(id: params[:a_id])
        if !hsa_query.empty?
          @hsa = hsa_query.first
          if params[:id].present?
            name_query = @hsa.named_faces.where(id: params[:id])
            if !name_query.empty?
              @named_face = name_query.first
            else
              @errors += ['Name not found']
            end
          else
            @named_faces = @hsa.named_faces.includes(:face_icon)
          end
        else
          @errors += ['Account not found']
        end
      end
    end

    # Only allow the white list through.
    def name_params
      params.require(:name).permit(:a_id)
    end

  end
end
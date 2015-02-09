module Api
  module V1
    class NamesController < ApplicationController

      # GET /a/:a_id/names
      def index
        @hsa = HostingServiceAccount.find(params[:a_id])
        @named_faces = @hsa.named_faces
      end

    private

      # Only allow the white list through.
      def name_params
        params.require(:name).permit(:a_id)
      end
    end
  end
end
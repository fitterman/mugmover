module Api
  module V1
    class UploadsController < ApiController
      def create
        request = ActiveSupport::JSON.decode(params[:data])
        require 'pp' ; pp request
        result = {status: "ok"}
        render json: result 
      end

    private

    end
  end
end
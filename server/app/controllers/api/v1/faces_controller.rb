module Api
  module V1
    # TODO Get this back to using ApiController
    class FacesController < ApplicationController

      def create
        errors = []
        if (hosting_service_account = HostingServiceAccount.find(params[:a_id]))
          if (photo = hosting_service_account.photos.find(params[:photo_id]))

            data = [{
                      "uuid" => 'ffffffff',  # TODO Figure out what to fill this in with
                      "faceNameUuid" => nil,
                      "keyVersionUuid" => nil,
                      "manual" => true,
                      "visible" => true,
                      "width" => 64,
                      "height" => 63,
                      "center" => {"x" => params[:x].to_i, "y" => params[:y].to_i},
                      "faceKey" => '99999999'  # TODO Fix this as well
                   }]
            @face, face_errors = Face.from_hash(hosting_service_account, 'ffffffff', photo, data) # TODO Fix the database_uuid
            if face_errors.present?
              errors += face_errors.values.first
            end
          else
            errors += ['Photo not found']
          end
        else
          errors += ['Account not found']
        end
        if errors.empty?
          result = {status: 'ok', face: @face}
          render json: result 
        else
          result = {status: 'fail', errors: errors}
          render json: result, status: :bad_request
        end
      end

      # mark the face as logically deleted
      def destroy
        errors = []
        if (@hsa = HostingServiceAccount.find(params[:a_id]))
          if (@photo = @hsa.photos.find(params[:photo_id]))
            if (@face = @photo.faces.find(params[:id]))
              @face.destroy # it's a logical deletion
            else
              errors += ['Face not found']
            end
          else
            errors += ['Photo not found']
          end
        else
          errors += ['Account not found']
        end
        if errors.empty?
          result = {status: 'ok', face: @face}
          render json: result 
        else
          result = {status: 'fail', errors: errors}
          render json: result, status: :bad_request
        end
      end

      # restore a logically deleted face back to the active (undeleted) state
      def undestroy
        errors = []
        if (@hsa = HostingServiceAccount.find(params[:a_id]))
          if (@photo = @hsa.photos.find(params[:photo_id]))
            if (@face = @photo.faces.only_deleted.find(params[:id]))
              @face.restore # undo the logical deletion (TODO Why isn't this "recover"?)
            else
              errors += ['Deleted face not found']
            end
          else
            errors += ['Photo not found']
          end
        else
          errors += ['Account not found']
        end
        if errors.empty?
          result = {status: 'ok', face: @face}
          render json: result 
        else
          result = {status: 'fail', errors: errors}
          render json: result, status: :bad_request
        end
      end

    end
  end
end
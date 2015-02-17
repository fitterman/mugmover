module Api
  module V1
    # TODO Get this back to using ApiController
    class FacesController < ApplicationController
      skip_before_action :verify_authenticity_token

      def create
        errors = []
        if (hosting_service_account = HostingServiceAccount.find(params[:a_id]))
          if (photo = hosting_service_account.photos.find(params[:photo_id]))
            @face = Face.new({
                              face_uuid: 'ffffffff',  # TODO Figure out what to fill this in with
                              face_key:  '99999999',  # TODO Fix this as well
                              visible: true,          # TODO Confirm the face is visible rather than setting it!
                              manual: true,
                              height: params[:h],
                              photo_id: params['photo_id'],
                              width: params[:w], 
                              x: params[:x],
                              y: params[:y],
                             });
            if !@face.save
              errors += @face.errors.full_messages
            end
          else
            errors += ['Photo not found']
          end
        else
          errors += ['Account not found']
        end
        if errors.empty?
          photo = @face.photo
          render partial: 'api/v1/faces/show', locals: {face: @face}
        else
          result = {status: 'fail', errors: errors}
          render json: result, status: :bad_request
        end
      end

      # link an existing facename to a face
      def link
        errors = []
        named_face = nil
        if (hsa = HostingServiceAccount.find(params[:a_id]))
          if (@photo = hsa.photos.find(params[:photo_id]))
            if (@face = @photo.faces.find(params[:id]))
              named_face = hsa.named_faces.find(params[:name_id])
              if (named_face)
                @face.named_face_id = named_face.id
                if !@face.save
                  errors += @face.errors.full_messages
                end
              else
                errors += ['Named face not found']
              end
            else
              errors += ['Face not found']
            end
          else
            errors += ['Photo not found']
          end
        else
          errors += ['Account not found']
        end
        if errors.any?
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
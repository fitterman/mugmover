module Api
  module V1
    # TODO Get this back to using ApiController
    class FacesController < ApplicationController
      skip_before_action :verify_authenticity_token
      before_action :pre_validation

      def create
        errors = []
        if @hsa && @photo
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
        end
        if errors.empty?
          photo = @face.photo
          render partial: 'api/v1/faces/show', locals: {face: @face}
        else
          result = {status: 'fail', errors: @errors}
          render json: result, status: :bad_request
        end
      end

      # link an existing facename to a face
      def link
        if @hsa && @photo
          named_face = nil
          if (@face = @photo.faces.where(id: params[:id]).first)
            named_face = @hsa.named_faces.where(id: params[:name_id].first)
            if (named_face)
              @face.named_face_id = named_face.id
              if !@face.save
                @errors += @face.errors.full_messages
              end
            else
              @errors += ['Named face not found']
            end
          else
            @errors += ['Face not found']
          end
        end
        if @errors.any?
          result = {status: 'fail', errors: @errors}
          render json: result, status: :bad_request
        end
      end

      # If the face was manually added and has no name associated with it,
      # a logical deletion will occur. Otherwise, the face will be logically
      # deleted. The response indicates what action occurred via the 
      # "destroyed" value.
      def destroy
        errors = []
        if @hsa && @photo
          if @face
            if @face.manual && @face.named_face_id.nil?
              @face.really_destroy!   # we really are deleting this record
            else
              @face.destroy!          # it's a logical deletion
            end
          else
            @errors += ['Face not found']
          end
        end
        if @errors.empty?
          render partial: 'api/v1/faces/show', locals: {face: @face}
        else
          result = {status: 'fail', errors: @errors}
          render json: result, status: :bad_request
        end
      end

      # Undo the logical deletion of a face (brought about by a reject action)
      def restore
        if @hsa && @photo
          if (@face = @photo.faces.only_deleted.where(id: params[:id]).first)
            @face.restore # undo the logical deletion (TODO Why isn't this "recover"?)
          else
            @errors += ['Deleted face not found']
          end
        end
        if @errors.empty?
          render partial: 'api/v1/faces/show', locals: {face: @face}
        else
          result = {status: 'fail', errors: @errors}
          render json: result, status: :bad_request
        end
      end

    protected
      def pre_validation
        @errors = []
        hsa_query = HostingServiceAccount.where(id: params[:a_id])
        if !hsa_query.empty?
          @hsa = hsa_query.first
          photo_query = @hsa.photos.where(id: params[:photo_id])
          if !photo_query.empty?
            @photo = photo_query.first
            if params[:id].present?
              @face = @photo.faces.where(id: params[:id]).first
            end
          else
            @errors += ['Photo not found']
          end
        else
          @errors += ['Album not found']
        end
      end
    end
  end
end
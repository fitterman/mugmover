class ForceRollbackError < StandardError ; end

module Api
  module V1
    class UploadsController < ApiController
      def create
        request = ActiveSupport::JSON.decode(params[:data])
        errors, service_account, photo, faces = store_uploaded_objects(request)
        if errors.empty?
          result = {status: 'ok'}
          render json: result 
        else
          result = {status: 'fail', errors: errors}
          render json: result, status: :bad_request
        end
      end

    private
      def store_uploaded_objects(request)
        # Create an untainted copy of the request, as we're going to save it with the photo
        pristine_request = request.dup

        errors = {} # Give it scope

        Photo.transaction do
          
          # Separate the properties you will need
          photo_hash = request['photo']
          service_hash = request.delete('service')
          database_uuid = request['source']['databaseUuid']

          hosting_service_account = HostingServiceAccount.from_request(service_hash)
          if hosting_service_account.errors.present?
            errors[:service] = hosting_service_account.errors.full_messages
          else
            photo = Photo.from_request(hosting_service_account, database_uuid, service_hash, photo_hash)
            if photo.errors.present?
              errors[:photo] = photo.errors.full_messages
            else
              # This creates the face and its associated objects, unless it finds existing ones
              faces, face_errors = Face.from_request(hosting_service_account, database_uuid, photo, request['faces'])
              if face_errors.present?
                errors[:face] = face_errors
              end
            end
          end

          if errors.empty?
            return [errors, hosting_service_account, photo, faces]
          end

          # One or more errors... abort the transaction, then return the errors
          raise ActiveRecord::Rollback

        end # of the transaction

        return [errors, nil, nil, []]
      end
    end
  end
end
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
        begin
          Photo.transaction do
            
            # Separate the properties you will need
            photo_hash = request['photo']
            service_hash = request.delete('service')
            service_name = service_hash.delete('name')
            if service_name == "flickr"

              # Determine which account this is associated with
              hosting_service_account = HostingServiceAccount.find_or_create_by(name: 'flickr', 
                                                                                handle: service_hash['owner']) do |new_hsa|
                if !new_hsa.save
                  errors[:service] = new_hsa.errors.full_messages
                  raise ForceRollbackError
                end
              end
            else
              errors[:service] = ['Name missing or not recognized']
              raise ForceRollbackError # Don't even bother processing photo or face data
            end

            database_uuid = request['source']['databaseUuid']

            photo = Photo.from_request(hosting_service_account, database_uuid, service_hash, photo_hash)
            if !photo.save
              errors[:photo] = photo.errors.full_messages
              raise ForceRollbackError  # Don't even bother processing face data
            end

            faces, face_errors = Face.from_request(hosting_service_account, database_uuid, photo, request['faces'])
            if face_errors.present?
              errors[:face] = face_errors
              raise ForceRollbackError
            end

            return [errors, hosting_service_account, photo, faces]
          end           
        rescue ForceRollbackError => e
          return [errors, nil, nil, []]
        end
      end
    end
  end
end
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

        # Separate the properties you will need

        errors = {} # Give it scope

        begin
          Photo.transaction do
            photo_hash = request['photo']
            service_hash = request.delete('service')
            service_name = service_hash.delete('name')
            if service_name == "flickr"
              service_photo_id = service_hash['id']

              # Determine which account this is associated with
              hosting_service_account = HostingServiceAccount.find_or_create_by(name: 'flickr', 
                                                                                handle: service_hash['owner']) do |new_hsa|
                if !new_hsa.save
                  errors[:service] = new_hsa.errors.full_messages
                  raise StandardError.new("Aborting")
                end
              end
            else
              errors[:service] = ['Name missing or not recognized']
              raise StandardError.new("Aborting")
            end

            photo = Photo.find_or_create_by(hosting_service_account_id: hosting_service_account.id,
                                            hosting_service_photo_id: service_photo_id) do |new_user|
            end
            photo.width = service_hash.delete('width') || photo_hash['width']
            photo.height = service_hash.delete('height') || photo_hash['height']
            photo.version_uuid = photo_hash['versionUuid']
            photo.master_uuid = photo_hash['masterUuid']
            photo.database_uuid = request['source']['databaseUuid']
            photo.original_date = photo_hash['original_date']
            photo.request = pristine_request

            if !photo.save
              errors[:photo] = photo.errors.full_messages
              raise StandardError.new("Aborting")
            end

            faces = request['faces'].map do |face_params|
              face_uuid = face_params['uuid']
              # TODO Determine role of FaceKey vs face.uuid over time
              # TODO, you might want to update more fields outside of the "new_named_face" block, depending on their life cycle
              named_face = NamedFace.find_or_create_by(hosting_service_account_id: hosting_service_account.id,
                                                       database_uuid: request['source']['databaseUuid'],
                                                       face_name_uuid: face_params['faceNameUuid']) do |new_named_face|
                new_named_face.face_key = face_params['faceKey']

                if !new_named_face.save
                  errors[:face] ||= {}
                  errors[:face][face_uuid] ||= []
                  errors[:face][face_uuid] += new_named_face.errors.full_messages
                  raise StandardError.new("Aborting")
                end
              end
              display_name = DisplayName.find_or_create_by(name: face_params['name'],
                                                           named_face_id: named_face.id) do |new_face_name|
                if !new_face_name.save
                  errors[:face] ||= {}
                  errors[:face][face_uuid] ||= []
                  errors[:face][face_uuid] += new_face_name.errors.full_messages
                  raise StandardError.new("Aborting")
                end
              end
              if named_face.primary_display_name_id.nil?
                named_face.primary_display_name_id = display_name.id
                if !named_face.save
                  errors[:face] ||= {}
                  errors[:face][face_uuid] ||= []
                  errors[:face][face_uuid] += named_face.errors.full_messages
                  raise StandardError.new("Aborting")
                end
              end

    ### TODO USE             "keyVersionUuid": "fI6GK4epTPKYbC76qREiVg",

              face = Face.find_or_create_by(photo_id: photo.id, face_uuid: face_uuid)
              face.named_face_id = named_face.id
              face.center_x = face_params['center']['x']
              face.center_y = face_params['center']['y']
              face.width = face_params['width']
              face.height = face_params['height']
              face.ignore = face_params['ignore']
              face.rejected = face_params['rejected']
              face.visible = face_params['visible']
              if !face.save
                errors[:face] ||= {}
                errors[:face][face_uuid] ||= []
                errors[:face][face_uuid] += face.errors.full_messages
                raise StandardError.new("Aborting")
              end
              face # Need this here so the .map collects all the faces
            end
            if errors.any?
               raise StandardError.new("Aborting")
            end
            return [errors, hosting_service_account, photo, faces]
          end           
        rescue # StandardError => e
          return [errors, nil, nil, []]
        end
      end
    end
  end
end
class Face < ActiveRecord::Base

  acts_as_paranoid                  # logical deletion support

  belongs_to  :photo
  belongs_to  :named_face

  validates   :photo_id,            presence: true
  validates   :face_uuid,           presence: true
  validates   :x,                   presence: true # could be negative after cropping
  validates   :y,                   presence: true # could be negative after cropping
  validates   :width,               numericality: { greater_than_or_equal_to: 0 }
  validates   :height,              numericality: { greater_than_or_equal_to: 0 }
  validates   :face_key,            presence: true

      #   #  ###  ##### ####   
      ##  # #   #   #   #       While the source data works with the center
      # # # #   #   #   ###     X and Y coordinates of the face, in the
      #  ## #   #   #   #       server, we track X and Y as the top left corner.
      #   #  ###    #   ####


  ## TODO Add rejected and figure out how manually-added faces are treated (vs automatic and rejected).
  ## Also add the facekey which associates a face to a name. Add the facekey in the person table
  
  def primary_name
    self.face_uuid
  end

  # This is the core of the face upload code, invoked by the UploadsController
  # When it is successful, it will return an array of Face objects and and a hash
  # of errors (the keys are the UUID of the face that had the problem and the 
  # values are an array of error strings). If the error has is empty, then no errors
  # were detected. If there are errors, it is up to the caller (who should invoke this
  # inside a transaction) to abort the transaction, otherwise assorted objects
  # that may have been created, including _some_ of the faces, will be left 
  # hanging around.

  def self.from_hash(hosting_service_account, database_uuid, photo, face_array, options={force: false})
    face_errors = {}
    faces = face_array.map do |face_params|
      ## face_key is filled in for every face, but face_name_uuid is only present if the 
      ## face has a FaceName associaed with it
      face_uuid = face_params['uuid']
      face_name_uuid = face_params['faceNameUuid']
      named_face = nil  # clear out the previous one

      unless face_name_uuid.blank?
        # TODO Determine role of FaceKey vs face.uuid over time
        # TODO, you might want to update more fields outside of the "new_named_face" block, depending on their life cycle
        named_face = NamedFace.find_or_create_by(hosting_service_account_id: hosting_service_account.id,
                                                 database_uuid: database_uuid,
                                                 face_name_uuid: face_name_uuid) do |new_named_face|
          new_named_face.face_key = face_params['faceKey']
          new_named_face.face_name_uuid = face_params['faceNameUuid']

          # IMPORTANT: If the face exists already, we do not update the name from the upload information
          new_named_face.private_name = face_params['name']
          # NOTE: We intentionally do not set the public name as it (and the notes) are initially
          #       derived from what is in the private name.
          if !new_named_face.save
            face_errors[face_uuid] ||= []
            face_errors[face_uuid] += new_named_face.errors.full_messages
          end
        end
      end

### TODO USE             "keyVersionUuid": "fI6GK4epTPKYbC76qREiVg",

      if options[:force] # Then you MUST create a new object
        face = Face.create(photo_id: photo.id, face_uuid: face_uuid)
      else
        face = Face.find_or_create_by(photo_id: photo.id, face_uuid: face_uuid)
      end
      if named_face.present?
        face.named_face_id = named_face.id
      end

      face.x = face_params['center']['x'] - (face_params['width'] / 2)
      face.y = face_params['center']['y'] - (face_params['height'] / 2)
      face.width = face_params['width']
      face.height = face_params['height']
      face.visible = face_params['visible']
      face.face_key = face_params['faceKey']
      face.manual = face_params['manual']
      if face_params['ignore'] || face_params['rejected']
        # If it's marked as ignore or rejected, treat it as logically deleted
        face.deleted_at = Time.now
      end
      if !face.save
        face_errors[face_uuid] ||= []
        face_errors[face_uuid] += face.errors.full_messages
      end
      face # Need this here so the .map collects all the faces
    end
    face_errors.each {|k, v| v.uniq!}  # When the faceKey is missing, for example, it can be reported twice
    return [faces, face_errors]
  end

end

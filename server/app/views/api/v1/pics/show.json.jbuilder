json.extract! @photo, :id
json.url @photo.big_url
json.flag @photo.flag?
notes = @photo.faces.map do |face|
          { x: face.left_scaled(@photo.scale_factor),
            y: face.top_scaled(@photo.scale_factor),
            w: face.width_scaled(@photo.scale_factor),
            h: face.height_scaled(@photo.scale_factor), 
            text: face.face_uuid }
        end
json.notes notes 

json.extract! @photo, :id
json.url @photo.big_url
json.flag @photo.flag?
notes = @photo.faces.map do |face|
          { x: face.left_scaled(@photo.scale_factor),
            y: face.top_scaled(@photo.scale_factor),
            w: face.width_scaled(@photo.scale_factor),
            h: face.height_scaled(@photo.scale_factor), 
            known: face.named_face.present?,
            manual: face.manual?,
            text: face.named_face.present? ? face.named_face.public_name : nil,
            faceId: face.id }
        end
json.notes notes 

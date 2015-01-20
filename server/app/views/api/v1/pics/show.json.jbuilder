json.extract! @photo, :id
json.url @photo.big_url
notes = @photo.faces.map do |face|
          {x: face.left_scaled(@photo.scale_factor),
           y: face.top_scaled(@photo.scale_factor),
           w: face.width_scaled(@photo.scale_factor),
           h: face.height_scaled(@photo.scale_factor), 
           text: "face.notenote._content"}
        end
json.notes notes 

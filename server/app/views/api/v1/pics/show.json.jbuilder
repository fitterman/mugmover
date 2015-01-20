json.extract! @photo, :id
json.url @photo.big_url
notes = @photo.faces.map do |face|
          {x: face.left, y: face.top, w: face.width, h: face.height, text: "face.notenote._content"}
        end
json.notes notes 

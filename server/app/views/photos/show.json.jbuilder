json.extract! @photo, :id
json.url FlickRaw.url(@photo)
notes = @photo.notes.map do |note|
          {x: note.x, y: note.y, w: note.w, h: note.h, text: note._content}
        end
json.notes notes 

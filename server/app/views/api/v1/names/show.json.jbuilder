json.partial! 'show', name: @named_face
json.faces do
  @faces.each do |face|
    json.partial! 'face', face: face
  end
end
class NamedFace < ActiveRecord::Base

  belongs_to  :hosting_service_account
  has_many    :faces do
                def sharpest
                  order('thumbscale DESC').first
                end
  end
  has_one     :face_icon,              class_name: 'Face'

  default_scope { order('public_name') }

  validates   :face_key,               presence: {allow_blank: false}
  validates   :face_name_uuid,         presence: {allow_blank: false}
  validates   :private_name,           presence: {allow_blank: false}
  validates   :public_name,            presence: {allow_blank: false}

  before_validation :look_for_parenthetical_and_normalize_names

  def look_for_parenthetical_and_normalize_names
    if self.note.blank? && self.private_name.present?
      puts "   ** private_name=#{private_name}"
      # Look for something in the private name in parens and if it's there,
      # name what's in the parens, the note, removing it from the private_name
      self.private_name.sub!(%r{\(([^\)]+)\)}) do |match|
        self.note = $1;
        ''
      end
    end

    # Now normalize the names (remove double white space, converting it all to a space character)
    self.private_name = self.private_name.to_s.split.join(' ')
    if self.public_name.blank?
      self.public_name = self.private_name
    end
    self.public_name = self.public_name.to_s.split.join(' ')
    self.note = self.note.to_s.split.join(' ')
  puts "   ++ private_name=#{self.private_name}", "   ++ note=#{self.note}"
  end

  def png_thumbnail
    Base64.encode64(open('/Users/bob/Downloads/logo-200x200.png') { |io| io.read })
  end
end
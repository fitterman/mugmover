class DisplayName < ActiveRecord::Base

  validates   :name,          presence: {allow_blank: false}

end
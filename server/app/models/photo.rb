class Photo < ActiveRecord::Base

  validates   :provider,    inclusion: %w{flickr}
  validates   :account,     inclusion: %w{127850168@N06}
  validates   :unique_id,   presence: true

  def initialize(params={})
    super
    self.provider = "flickr"
    self.account = "127850168@N06"
  end

end

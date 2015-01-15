class HostingServiceAccount < ActiveRecord::Base

  validates   :name,         inclusion: %w{flickr}
#  validates   :handle,       inclusion: %w{127850168@N06}
#  validates   :auth_token,   presence: true


end
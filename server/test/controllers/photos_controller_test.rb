require 'test_helper'

class PhotosControllerTest < ActionController::TestCase
  setup do
    @photo = photos(:one)
  end

  test "photo index is reachable" do
    puts 'TODO: test "photo index is reachable" is disabled. Do we need it?'
#    get :index
#    assert_response :success
  end

end

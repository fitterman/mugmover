require 'test_helper'

class UploadsControllerTest < ActionController::TestCase
  setup do
    @controller = Api::V1::UploadsController.new
    @json = load_string_fixture_from_file('single_face_upload.json')
  end

  test "should create upload" do
    assert_difference('HostingServiceAccount.count') do
      assert_difference('Photo.count') do
        assert_difference('Face.count') do
          assert_difference('NamedFace.count') do
           assert_difference('DisplayName.count') do
              post :create, data: @json, format: 'json'
              assert_response :success
              response_data_structure = JSON.parse(@response.body)
              assert_equal 'application/json', @response.content_type
              assert_equal({'status' => 'ok'}, response_data_structure)
            end
          end
        end
      end
    end
  end

test "should reject missing a parameter needed for a HostingServiceAccount object" do
      hash = JSON.parse(@json)
    hash['service']['name'] = 'snapfish'
    assert_no_difference('HostingServiceAccount.count') do
      assert_no_difference('Photo.count') do
        assert_no_difference('Face.count') do
          assert_no_difference('NamedFace.count') do
             assert_no_difference('DisplayName.count') do
                post :create, data: hash.to_json, format: 'json'
                assert_response :bad_request
                response_data_structure = JSON.parse(@response.body)
                assert_equal 'application/json', @response.content_type
                assert_equal('fail', response_data_structure['status'])
                assert_equal({'service' => ['Name is not included in the list']},
                             response_data_structure['errors'])
            end
          end
        end
      end
    end
  end

  test "should reject missing a parameter needed for a Photo object" do
    hash = JSON.parse(@json)
    hash['photo'].delete('masterUuid')
    assert_no_difference('HostingServiceAccount.count') do
      assert_no_difference('Photo.count') do
        assert_no_difference('Face.count') do
          assert_no_difference('NamedFace.count') do
            assert_no_difference('DisplayName.count') do
              post :create, data: hash.to_json, format: 'json'
              assert_response :bad_request
              response_data_structure = JSON.parse(@response.body)
              assert_equal 'application/json', @response.content_type
              assert_equal('fail', response_data_structure['status'])
              assert_equal({'photo' => ['Master uuid can\'t be blank']},
                           response_data_structure['errors'])
            end
          end
        end
      end
    end
  end

  test "should reject missing a parameter needed for a FaceName object" do
    hash = JSON.parse(@json)
    hash['faces'].first['faceKey'] = nil
    assert_no_difference('HostingServiceAccount.count') do
      assert_no_difference('Photo.count') do
        assert_no_difference('Face.count') do
          assert_no_difference('NamedFace.count') do
            assert_no_difference('DisplayName.count') do
              post :create, data: hash.to_json, format: 'json'
              assert_response :bad_request
              response_data_structure = JSON.parse(@response.body)
              assert_equal 'application/json', @response.content_type
              assert_equal('fail', response_data_structure['status'])
              assert_equal({'face' => {"Bov8U7u1RZiHPGG+b6N1vg" => ["Face key can't be blank"]}},
                           response_data_structure['errors'])
            end
          end
        end
      end
    end
  end

  test "should reject missing a parameter needed for a DisplayName object" do
    hash = JSON.parse(@json)
    hash['faces'].first['name'] = ''
    assert_no_difference('HostingServiceAccount.count') do
      assert_no_difference('Photo.count') do
        assert_no_difference('Face.count') do
          assert_no_difference('NamedFace.count') do
            assert_no_difference('DisplayName.count') do
              post :create, data: hash.to_json, format: 'json'
              assert_response :bad_request
              response_data_structure = JSON.parse(@response.body)
              assert_equal 'application/json', @response.content_type
              assert_equal('fail', response_data_structure['status'])
              assert_equal({'face' => {"Bov8U7u1RZiHPGG+b6N1vg" => ["Name can't be blank"]}},
                           response_data_structure['errors'])
            end
          end
        end
      end
    end
  end

  # This test submits the same information twice. The point is to be sure that
  # even in this situation, no duplicate objects are created. They should be updated.
  # However, if something were to change, aside from the things that uniquely
  # identify the source objects, those fields should change. Changing the unique
  # keys, of course, would cause one or more new objects to be created.
  test "should not create duplicate objects" do
    assert_difference('HostingServiceAccount.count') do
      assert_difference('Photo.count') do
        assert_difference('Face.count') do
          assert_difference('NamedFace.count') do
            assert_difference('DisplayName.count') do
              post :create, data: @json, format: 'json'
              assert_response :success
              response_data_structure = JSON.parse(@response.body)
              assert_equal 'application/json', @response.content_type
              assert_equal({'status' => 'ok'}, response_data_structure)

              post :create, data: @json, format: 'json'
              assert_response :success
              response_data_structure = JSON.parse(@response.body)
              assert_equal 'application/json', @response.content_type
              assert_equal({'status' => 'ok'}, response_data_structure)
            end
          end
        end
      end
    end
  end

end

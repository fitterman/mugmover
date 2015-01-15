ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def load_string_fixture_from_file(filename)
    path = File.join(Rails.root, 'test/fixtures', filename)
    return File.read(path)
  end

  def load_json_fixture_from_file(filename)
    return JSON.parse(load_string_fixture_from_file(filename))
  end
end

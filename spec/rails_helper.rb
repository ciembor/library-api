require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = false
  config.filter_rails_from_backtrace!
end

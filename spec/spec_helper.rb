unless ENV["SIMPLECOV_ENABLED"] == "false"
  require "simplecov"

  SimpleCov.start "rails" do
    enable_coverage :branch
    primary_coverage :line
    coverage :line do
      minimum 100
      minimum 100, per: :file
    end
    coverage :branch do
      minimum 100
      minimum 100, per: :file
    end
    cover "app/**/*.rb"
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.order = :random
end

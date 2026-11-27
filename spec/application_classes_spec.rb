require "rails_helper"

RSpec.describe "application base classes" do
  it "loads each application base class" do
    expect(ApplicationController).to be < ActionController::API
    expect(ApplicationJob).to be < ActiveJob::Base
    expect(ApplicationMailer).to be < ActionMailer::Base
    expect(ApplicationRecord).to be < ActiveRecord::Base
  end
end

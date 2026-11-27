# Base mailer for messages sent by the library.
class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"
end

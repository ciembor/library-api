# Base model for records stored by the application.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end

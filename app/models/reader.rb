# A registered library reader identified by card number and email.
class Reader < ApplicationRecord
  has_many :borrowings, inverse_of: :reader

  validates :library_card_number, presence: true, numericality: { only_integer: true, greater_than: 99_999, less_than: 1_000_000 }, uniqueness: true
  validates :full_name, :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }, allow_blank: true

  def api_data
    { library_card_number: library_card_number, full_name: full_name, email: email }
  end
end

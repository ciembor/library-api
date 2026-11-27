# A library-owned copy; availability follows its active borrowing.
class Book < ApplicationRecord
  has_many :borrowings, inverse_of: :book
  has_one :active_borrowing, -> { where(returned_at: nil) }, class_name: "Borrowing"

  validates :serial_number, presence: true, numericality: { only_integer: true, greater_than: 99_999, less_than: 1_000_000 }, uniqueness: true
  validates :title, :author, presence: true

  def status
    active_borrowing ? "borrowed" : "available"
  end

  def api_data(borrowings: nil)
    data = { serial_number: serial_number, title: title, author: author, status: status }
    data[:borrowings] = borrowings.map(&:api_data) if borrowings
    data
  end
end

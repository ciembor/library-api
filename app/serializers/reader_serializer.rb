# Serializes a registered reader without persistence concerns.
class ReaderSerializer
  def initialize(reader)
    @reader = reader
  end

  def as_json(*)
    { library_card_number: @reader.library_card_number, full_name: @reader.full_name, email: @reader.email }
  end
end

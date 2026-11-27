require "rails_helper"
require "timeout"

# Coordinates concurrent operations that must acquire independent database connections.
class ConcurrentOperations
  WAIT_TIMEOUT = 5.seconds

  # Holds the queues and workers for one synchronized run.
  State = Struct.new(:operations, :ready, :release, :outcomes, :threads, keyword_init: true)

  def initialize(operations)
    @state = State.new(operations: operations, ready: Queue.new, release: Queue.new, outcomes: Queue.new)
  end

  def call
    start_workers
    wait_for_workers
    release_workers
    collect_outcomes
  ensure
    stop_workers
  end

  private

  def start_workers
    @state.threads = @state.operations.map { |operation| Thread.new { perform(operation) } }
  end

  def wait_for_workers
    @state.operations.size.times { Timeout.timeout(WAIT_TIMEOUT) { @state.ready.pop } }
  end

  def release_workers
    @state.operations.size.times { @state.release << true }
  end

  def collect_outcomes
    @state.threads.each { |thread| thread.join(WAIT_TIMEOUT) || raise(Timeout::Error, "concurrent operation did not finish") }
    @state.operations.size.times.map { @state.outcomes.pop }
  end

  def stop_workers
    @state.threads&.each(&:kill)
  end

  def perform(operation)
    ActiveRecord::Base.connection_pool.with_connection do |connection|
      execute_operation(connection, operation)
    rescue BorrowingConflict => error
      record_outcome(connection, error.class)
    end
  end

  def execute_operation(connection, operation)
    @state.ready << true
    @state.release.pop
    operation.call
    record_outcome(connection, nil)
  end

  def record_outcome(connection, error)
    @state.outcomes << { backend_pid: connection.raw_connection.backend_pid, error: error }
  end
end

RSpec.describe "borrowing concurrency" do
  uses_transaction "allows only one concurrent borrowing for a book"
  uses_transaction "allows only one concurrent return for a borrowing"

  before do
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE borrowing_reminders, borrowings, books, readers RESTART IDENTITY CASCADE")
  end

  after do
    ActiveRecord::Base.connection.execute("TRUNCATE TABLE borrowing_reminders, borrowings, books, readers RESTART IDENTITY CASCADE")
  end

  it "allows only one concurrent borrowing for a book" do
    book = Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert")
    readers = [ [ 654_321, "Ada Lovelace", "ada@example.com" ], [ 654_322, "Grace Hopper", "grace@example.com" ] ].map do |card_number, full_name, email|
      Reader.create!(library_card_number: card_number, full_name: full_name, email: email)
    end
    operations = readers.map do |reader|
      -> { BorrowBook.new(serial_number: book.serial_number, library_card_number: reader.library_card_number, borrowed_at: Time.utc(2026, 11, 27, 12)).call }
    end

    outcomes = ConcurrentOperations.new(operations).call

    expect(outcomes.count { |outcome| outcome[:error].nil? }).to eq(1)
    expect(outcomes.map { |outcome| outcome[:error] }).to include(BorrowingConflict)
    expect(outcomes.map { |outcome| outcome[:backend_pid] }.uniq).to have_attributes(size: 2)
    expect(Borrowing.where(book: book, returned_at: nil).count).to eq(1)
    expect(Borrowing.where(book: book).count).to eq(1)
  end

  it "allows only one concurrent return for a borrowing" do
    book = Book.create!(serial_number: 123_456, title: "Dune", author: "Frank Herbert")
    reader = Reader.create!(library_card_number: 654_321, full_name: "Ada Lovelace", email: "ada@example.com")
    borrowing = Borrowing.create!(book: book, reader: reader, borrowed_at: Time.utc(2026, 11, 27, 12), due_at: Time.utc(2026, 12, 27, 12))
    operations = Array.new(2) do
      -> { ReturnBook.new(serial_number: book.serial_number, returned_at: Time.utc(2026, 11, 29, 12)).call }
    end

    outcomes = ConcurrentOperations.new(operations).call

    expect(outcomes.count { |outcome| outcome[:error].nil? }).to eq(1)
    expect(outcomes.map { |outcome| outcome[:error] }).to include(BorrowingConflict)
    expect(outcomes.map { |outcome| outcome[:backend_pid] }.uniq).to have_attributes(size: 2)
    expect(borrowing.reload.returned_at).to eq(Time.utc(2026, 11, 29, 12))
    expect(Borrowing.where(book: book).count).to eq(1)
  end
end

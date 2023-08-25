require_relative "../test_helper"

class TestLogger

  attr_reader :buffer

  def initialize
    @buffer = StringIO.new
  end

  def info(*data)
    buffer << data
  end

  alias_method :debug, :info
  alias_method :error, :info

  def read
    buffer.rewind
    buffer.read
  end
end

class Mock < OpenStruct
  include GlobalID::Identification
  GlobalID.app = "sidekiq-backgrounder"

  def model_name
    "Mock"
  end

  def self.find(id)
    new(id: id)
  end

  def run; end

  def exception_handler
  end

  def raise_exception
    raise "Exception!"
  end
end

class BareMock
  def run; end
end

class Honeybadger
  def self.notify(message, force: nil, fingerprint: nil, error_class: nil) end
end

class SidekiqBackgrounderTest < Minitest::Test

  attr_reader :subject, :logger

  def setup
    @logger = TestLogger.new
    SidekiqBackgrounder.configure do |config|
      config.logger = logger
      config.queue = "default"
    end

    @subject = SidekiqBackgrounder
  end

  def test_that_it_has_a_version_number
    refute_nil ::SidekiqBackgrounder::VERSION
  end

  def test_executes_method_on_instance_using_gid_identifier
    method_was_run = false
    Mock.stub_instances(:run, -> { method_was_run = true }) do
      subject.queue.perform_async("gid://sidekiq-backgrounder/Mock/1", "run")
    end
    assert method_was_run, "expected method to have been run"
    assert_match "SidekiqBackgrounder::Worker: running: Mock#run, method_args: nil", logger.read
  end

  def test_executes_method_on_instance_using_class_name
    method_was_run = false
    BareMock.stub_instances(:run, -> { method_was_run = true }) do
      subject.queue.perform_async("BareMock", "run")
    end
    assert method_was_run, "expected method to have been run"
    assert_match "SidekiqBackgrounder::Worker: running: BareMock#run, method_args: nil", logger.read
  end

  def test_executes_method_with_args_on_instance
    method_output = nil
    Mock.stub_instances(:run, ->(arg1, arg2) { method_output = "#{arg1}, #{arg2}" }) do
      subject.queue.perform_async("gid://sidekiq-backgrounder/Mock/1", "run", %w[data1 data2])
    end
    assert_equal "data1, data2", method_output
    assert_match "SidekiqBackgrounder::Worker: running: Mock#run, method_args: [\\\"data1\\\", \\\"data2\\\"]",
      logger.read
  end

  def test_uses_sidekiq_options
    Sidekiq::Testing.fake! do
      subject.
        queue(queue: "other_queue", retry: true, backtrace: false).
        perform_async("gid://sidekiq-backgrounder/Mock/1", "run", %w[data1 data2])
      job = Sidekiq::Worker.jobs.first
      assert job["retry"]
      refute job["backtrace"]
      assert_equal "other_queue", job["queue"]
    end
  end

  def test_executes_exception_handler_if_present
    exception_output = nil
    Mock.stub_instances(:run, -> { raise "Exception" }) do
      Mock.stub_instances(:exception_handler, ->(exception) { exception_output = "An exception occurred: #{exception}" }) do
        subject.queue.perform_async("gid://sidekiq-backgrounder/Mock/1", "run", nil, false, "exception_handler")
      end
    end

    assert_equal "An exception occurred: Exception", exception_output
  end

  def test_raises_an_exception_if_argument_given
    error = assert_raises(SidekiqBackgrounder::Error) {
      Mock.stub_instances(:run, -> { raise "Exception" }) do
        subject.queue.perform_async("gid://sidekiq-backgrounder/Mock/1", "run")
      end
    }

    assert_match "class: \"Mock\", method: \"run\" method_args: nil encountered_error: Exception", error.message
  end

  def test_uses_honeybadger_if_present_and_configured
    SidekiqBackgrounder.configure do |config|
      config.use_honeybadger = true
    end

    mock = Minitest::Mock.new
    mock.expect(:call, nil, [String], force: true, fingerprint: String, error_class: String)
    Honeybadger.stub(:notify, mock) do
      assert_raises(SidekiqBackgrounder::Error) {
        subject.queue.perform_async("gid://sidekiq-backgrounder/Mock/1", "raise_exception")
      }
    end
    mock.verify
  end
end



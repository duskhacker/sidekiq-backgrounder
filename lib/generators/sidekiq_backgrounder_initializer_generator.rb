class SidekiqBackgrounderInitializerGenerator < Rails::Generators::Base
  # :logger, :use_honeybadger, :queue, :retry, :backtrace, :pool, :raise_exception
  def create_initializer_file
    create_file "config/initializers/sidekiq_backgrounder.rb", <<~RUBY
      SidekiqBackgrounder.configure do |config|
        config.logger = Rails.logger
        config.queue = "default"
        config.retry = false
        config.backtrace = true
        config.use_honeybadger = false
        # config.pool = "some_pool_name"
      end
    RUBY
  end
end

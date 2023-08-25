require "sidekiq_backgrounder/version"
require "globalid"
require "sidekiq"
require "active_support"
require "error_extractor"

module SidekiqBackgrounder
  class Error < StandardError; end

  class Worker
    include Sidekiq::Worker

    attr_reader :object, :method, :gid_str, :exception_handler_method, :logger, :config

    def initialize
      @config = SidekiqBackgrounder.configuration
      @logger = config.logger
    end

    def perform(identifier, method, method_args = nil, raise_exception = true, exception_handler_method = nil)
      @object = if identifier.match(/gid:/)
                  GlobalID.new(identifier).find rescue nil
                else
                  identifier.constantize.new
                end
      logger.debug("#{object.class}: found/instantiated object ")

      if object.blank?
        logger.error "#{identifier.inspect} not found to call #{method.to_s.inspect} on, exiting..."
        return
      end
      @exception_handler_method = exception_handler_method

      begin
        logger.info "#{self.class}: running: #{object.class rescue object.inspect}##{method}, " +
          "method_args: #{method_args.inspect}"
        object.public_send(method, *method_args)
      rescue Exception => e
        if exception_handler_method.present?
          object.public_send(exception_handler_method, e)
        else
          msg = "class: \"#{object.to_gid.to_str rescue object.class.to_s || "N/A"}\", method: \"#{method}\" " +
            "method_args: #{method_args.inspect} encountered_error: #{extract_errors_with_backtrace(e)}"

          if defined?(:Honeybadger) && config.use_honeybadger
            Honeybadger.notify(
              msg,
              force: true,
              fingerprint: Digest::SHA1.hexdigest(msg),
              error_class: "SideKiqBackgrounder::Worker Error",
            )
          end

          unless raise_exception
            logger.error msg
            return
          end
          raise SidekiqBackgrounder::Error.new(msg)
        end
      end
    end
  end

  class << self
    attr_accessor :configuration

    def queue(options = {})
      c = SidekiqBackgrounder.configuration
      options.symbolize_keys!

      opts = %i(queue retry backtrace).inject({}) do |m, opt|
        m[opt] = c.public_send(opt)
        m[opt] = options[opt] if options.has_key?(opt)
        m
      end

      opts[:pool] = c.pool if c.pool.present?
      opts[:pool] = options[:pool] if options.has_key?(:pool).present?

      Worker.set(opts)
    end

    def configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end
  end

  class Configuration
    attr_accessor :logger, :use_honeybadger, :queue, :retry, :backtrace, :pool
  end
end
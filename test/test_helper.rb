$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "awesome_print"
require "ostruct"
require 'sidekiq/testing'
Sidekiq::Testing.inline!
require "sidekiq_backgrounder"

class Object
  def self.stub_instances(name, val_or_callable)
    new_name = "__minitest_any_instance_stub__#{name}"

    class_eval do
      alias_method new_name, name

      define_method(name) do |*args|
        (val_or_callable.respond_to? :call) ? instance_exec(*args, &val_or_callable) : val_or_callable
      end
    end

    yield
  ensure
    class_eval do
      undef_method name
      alias_method name, new_name
      undef_method new_name
    end
  end
end


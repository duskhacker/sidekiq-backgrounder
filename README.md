# SidekiqBackgrounder

SidekiqBackgrounder is a simple utility that abstracts the creation of a background job into a single class. The 
worker class takes a GlobalID string or class name, finds or instantiates the object as appropriate, then runs
a given method on the instance. 

This approach is appropriate when your application has classes that have operations that should work in the background.
The advantage is that a class's background processing code can be included in the class, rather than spread out 
over separately defined worker classes. This increases cohesiveness in the codebase. This approach also 
cuts down on boilerplate code needed to define workers. 

## Installation

### Bundler

    gem "sidekiq_backgrounder", "~> 0.1.0"

### Gem install

    $ gem install sidekiq_backgrounder

### Configuration

There is a configuration generator included in this gem for use in a rails project 

    $ rails generate sidekiq_backgrounder_initializer

If using outside of rails, configuration must be included manually: 

```
      SidekiqBackgrounder.configure do |config|
        config.logger = Rails.logger
        config.queue = "default"
        config.retry = false
        config.backtrace = true
        config.use_honeybadger = false
        # config.pool = "some_pool_name"
      end
```

#### Configuration options 

* `logger` - required. A logging object that responds to `:info` and `:debug`
* `queue` - Sidekiq queue option, required. A sidekiq queue name to queue a job to. Can be overridden in method call. 
* `retry` - Sidekiq queue option, required. Whether to retry failed jobs by default. Can be overridden in method call.
* `backtrace` - Sidekiq queue option, required. Whether to provide a backtrace when a job fails. Can be overridden in method call.
* `pool` - Sidekiq queue option, optional. A sidekiq pool name to use to point a job to a particular redis shard. 
   Can be overridden in method call. 
* `use_honeybadger` - required. If you use Honeybadger, enabling this option will force a Honeybadger notification.

## Usage

SidekiqBackgrounder uses [GlobalID](https://github.com/rails/globalid) to reference models backed a by database table.
If you are not using ActiveRecord, take a look at the tests to see hints on how to set up a class to use GlobalID 
manually. If the target instance is a plain ruby object, simply provide the class name.

This invocation will call the `run` method on the instance of the `Mock` class in a Sidekiq job:

    SidekiqBackgrounder.queue.perform_async("gid://sidekiq-backgrounder/Mock/1", "run")

This invocation will call the `run` method on an instance of the `BareMock` class in a Sidekiq job: 

    SidekiqBackgrounder.queue.perform_async("BareMock", "run")

### Sidekiq Queue Options 

All of the default Sidekiq queue options can be overridden in the queue method, an example:

    SidekiqBackgrounder.queue(queue: "priority1", pool: "us-east").perform_async("BareMock", "run")

### Full method signature for perform

    SidekiqBackgrounder.queue.perform_async(
        "class name | GlobalID", 
        "method", 
        method_args = nil,
        raise_exception = true,
        exception_handler_method = nil
    )

* `method_args` - Optionally pass arguments to the method. These must follow the rules of passing method arguments
                  to Sidekiq jobs. 
* `raise_exception` - Use this option to force the run not to raise an exception. 
* `exception_handler_method` - If provided, this method will be called on the object if an exception occurs instead
                               of the default actions for exceptions. 

## Testing/Debugging 

In case you want to test/debug your invocation directly, call `new` directly on the worker class, skipping the call to
`queue`:

    SidekiqBackgrounder::Worker.new.perform("Mock", "run")

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. 
You can also run `bin/console` for an interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/duskhacker/backgrounder.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

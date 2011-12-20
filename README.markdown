EM::Resque
==========

EM::Resque is an addition for [Resque][0] for asynchronic processing of the
background jobs created by Resque. It works like the original Resque worker,
but runs inside the [EventMachine][1] and uses instead of forking a new process
for every worker, it runs in a single process and packs the workers in Ruby
fibers.

Use cases
---------

EM::Resque is good for processing background jobs which are doing lots of IO.
The evented nature of the reactor core pattern is great when accessing third
party services with HTTP or doing lots of database-intensive work. When
combined with a connection pool to a SQL server it lets you easily control the
amount of connections being at the same time extremely scaleable.

When to use the original Resque
-------------------------------

If you do heavy computing with your workers and not using so much of IO, it is
recommended to use the synchronous Resque instead of EM::Resque. EM::Resque is
also not forking new processes for every task, so if using e.g. ActiveRecord
it doesn't initialize the database every time which would otherwise kill the
performance with short tasks. Although the original Resque is easier to fix
when something goes wrong by terminating the child processes. With EM::Resque
you have to take care of the main process, because all the workers are running
in the same thread.

Overview
--------

EM::Resque jobs are created and queued like with the synchronous version. When
queued, the one of the workers in the fiber pool will pick it up and process
the job.

When making IO actions inside the job, it should never block the other workers. E.g.
database operations should be handled with libraries that support EventMachine
to allow concurrent processing.

Resque jobs are Ruby classes (or modules) which respond to the
`perform` method. Here's an example:

``` ruby
class Pinger
  @queue = :ping_publisher

  def self.perform(url)
    self.url = url
    self.result = EventMachine::HttpRequest.new(url).get.response
    self.save
  end
end
```

The `@queue` class instance variable determines which queue `Pinger`
jobs will be placed in. Queues are arbitrary and created on the fly -
you can name them whatever you want and have as many as you want.

To place an `Pinger` job on the `ping_publisher` queue, we might add this
to our application's pre-existing `Callback` class:

``` ruby
class Callback
  def async_ping_publisher
    Resque.enqueue(Pinger, self.callback_url)
  end
end
```

Now when we call `callback.async_ping_publisher` in our
application, a job will be created and placed on the `ping_publisher`
queue.

For more use cases please refer [the original Resque manual][0].

Let's start 100 async workers to run `ping_publisher` jobs:

    $ cd app_root
    $ QUEUE=file_serve FIBERS=100 rake resque_async:work

This starts the EM::Resque process and loads 100 fibers with a worker inside
each fiber and tells them to work off the `ping_publisher` queue. As soon as
one of the workers is doing it's first IO action it will go to a waiting mode
to get data back from the IO and allow another one to start a new job. The
event loop resumes the workers when they have some data back from the IO
action.

The workers also reserve the jobs for them so other workers won't touch them.

Workers can be given multiple queues (a "queue list") and run on
multiple machines. In fact they can be run anywhere with network
access to the Redis server.

Jobs
----

What should you run in the background with EM::Resque? Anything with lots of
IO and which takes any time at all. Best use case is gathering data and sending
pings to 3rd party services, which might or might not answer in a decent time.

At SponsorPay we use EM::Resque to process the following types of jobs:

* Simple messaging between our frontend and backend softwares
* Pinging publishers and affiliate networks 

We're handling a tremendious amount of traffic with a bit over 100 workers,
using a lot less of database connections, memory and cpu power compared to the
synchronous and forking Resque or Delayed Job.

All the environment options from the original Resque work also in EM::Resque.
There are also couple of more variables.

### The amount of fibers

The number of fibers for the current process is set in FIBERS variable. One
fiber equals one worker. They are all polling the same queue and terminated
when the main process terminates. The default value is 1.

    $ QUEUE=ping_publisher FIBERS=50 rake resque_async:work

### The amount of green threads

EventMachine has an option to use defer for long-running processes to be run in
a different thread. The default value is 20.

    $ QUEUE=ping_publisher CONCURRENCY=20 rake resque_async:work

### Signals

EM:Resque workers respond to a few different signals:

* `QUIT` / `TERM` / `INT` - Wait for workers to finish processing then exit

The Front End
-------------

EM::Resque uses the same frontend as Resque. 

EM::Resque Dependencies
-----------------------

    $ gem install bundler
    $ bundle install

Installing EM::Resque
---------------------

### In a Rack app, as a gem

First install the gem.

    $ gem install em-resque

Next include it in your application.

``` ruby
require 'em-resque'
```

Now start your application:

    rackup config.ru

That's it! You can now create EM::Resque jobs from within your app.

To start a worker, create a Rakefile in your app's root (or add this
to an existing Rakefile):

``` ruby
require 'your/app'
require 'em-resque/tasks'
```

Now:

    $ QUEUE=* FIBERS=50 rake resque_async:work

Alternately you can define a `resque:setup` hook in your Rakefile if you
don't want to load your app every time rake runs.

### In a Rails 3 app, as a gem

First include it in your Gemfile.

    $ cat Gemfile
    ...
    gem 'em-resque'
    ...

Next install it with Bundler.

    $ bundle install

Now start your application:

    $ rails server

That's it! You can now create EM::Resque jobs from within your app.

To start the workers, add this to a file in `lib/tasks` (ex:
`lib/tasks/em-resque.rake`):

``` ruby
require 'em-resque/tasks'
```

Now:

    $ QUEUE=* FIBERS=50 rake environment resque_async:work

Don't forget you can define a `resque:setup` hook in
`lib/tasks/whatever.rake` that loads the `environment` task every time.

If using ActiveRecord or any other libraries with EM::Resque, you have to use
versions that support EventMachine. Otherwise every call to database etc. will
block all the other fibers in the process and kill the performance. 

Configuration
-------------

You may want to change the Redis host and port Resque connects to, or
set various other options at startup.

EM::Resque has a `redis` setter which can be given a string or a Redis
object. This means if you're already using Redis in your app, EM::Resque
can re-use the existing connection. EM::Resque is using the non-blocking
EM::Resque by default.

String: `Resque.redis = 'localhost:6379'`

Redis: `Resque.redis = $redis`

For our rails app we have a `config/initializers/em-resque.rb` file where
we load `config/resque.yml` by hand and set the Redis information
appropriately.

Here's our `config/resque.yml`:

    development: localhost:6379
    test: localhost:6379
    staging: localhost:6379
    production: db.sponsorpay.com:6379

And our initializer:

``` ruby
rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'

resque_config = YAML.load_file(rails_root + '/config/em-resque.yml')
EM::Resque.redis = resque_config[rails_env]
```

Easy peasy! Why not just use `RAILS_ROOT` and `RAILS_ENV`? Because
this way we can tell our Sinatra app about the config file:

    $ RAILS_ENV=production resque-web rails_root/config/initializers/resque.rb

Now everyone is on the same page.

Also, you could disable jobs queueing by setting 'inline' attribute.
For example, if you want to run all jobs in the same process for cucumber, try:

``` ruby
EM::Resque.inline = ENV['RAILS_ENV'] == "cucumber"
```

Namespaces
----------

If you're running multiple, separate instances of Resque you may want
to namespace the keyspaces so they do not overlap. This is not unlike
the approach taken by many memcached clients.

This feature is provided by the [redis-namespace][rs] library, which
Resque uses by default to separate the keys it manages from other keys
in your Redis server.

Simply use the `EM::Resque.redis.namespace` accessor:

``` ruby
EM::Resque.redis.namespace = "resque:GitHub"
```

We recommend sticking this in your initializer somewhere after Redis
is configured.

Contributing
------------

1. Fork EM::Resque
2. Create a topic branch - `git checkout -b my_branch`
3. Push to your branch - `git push origin my_branch`
4. Create a [Pull Request](http://help.github.com/pull-requests/) from your branch
5. That's it!

Meta
----

* Code: `git clone git://github.com/SponsorPay/em-resque.git`
* Home: <http://github.com/SponsorPay/em-resque>
* Bugs: <http://github.com/SponsorPay/em-resque/issues>
* Gems: <http://gemcutter.org/gems/em-resque>

Author
------

Julius de Bruijn :: julius.bruijn@sponsorpay.com :: @pimeys

[0]: http://github.com/defunkt/resque
[1]: http://rubyeventmachine.com/

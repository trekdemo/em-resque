require 'resque'
require 'em-synchrony'
require 'em-synchrony/em-redis'
require 'em-synchrony/connection_pool'
require 'uri'

module EM::Resque
  extend Resque

  def self.initialize_redis(server, pool_size = 1)
    case server
    when String
      opts = if server =~ /redis\:\/\//
               uri = URI.parse(server)
               {:host => uri.host, :port => uri.port}
             else
               server, namespace = server.split('/', 2)
               host, port, db = server.split(':')
               {:host => host, :port => port, :thread_safe => true, :db => db}
             end

      namespace ||= :resque

      redis = EventMachine::Synchrony::ConnectionPool.new(:size => pool_size) do
        EM::Protocols::Redis.connect(opts)
      end

      Resque.redis = Redis::Namespace.new(namespace, :redis => redis)
    when Redis::Namespace
      Resque.redis = server
    else
      Resque.redis = Redis::Namespace.new(namespace, :redis => server)
    end
  end
end

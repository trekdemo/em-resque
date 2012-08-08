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

        redis = EventMachine::Synchrony::ConnectionPool.new(:size => pool_size) do
          EM::Protocols::Redis.connect(opts)
        end
      when Redis::Namespace
        Resque.redis = server
      when Hash
        if server[:namespace]
          namespace = server[:namespace]
          server.delete(:namespace)
        end

        redis = EventMachine::Synchrony::ConnectionPool.new(:size => pool_size) do
          EM::Protocols::Redis.connect(server)
        end
      else
        redis = EventMachine::Synchrony::ConnectionPool.new(:size => pool_size) do
          server
        end
    end
    namespace ||= :resque
    Resque.redis = Redis::Namespace.new(namespace, :redis => redis)
  end
end

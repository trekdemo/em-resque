require 'resque'
require 'em-synchrony'
require 'em-synchrony/em-redis'
require 'uri'

module EM::Resque
  extend Resque

  def self.redis=(server)
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

      redis = EM::Protocols::Redis.connect(opts)

      Resque.redis = Redis::Namespace.new(namespace, :redis => redis)
    when Redis::Namespace
      Resque.redis = server
    else
      Resque.redis = Redis::Namespace.new(namespace, :redis => server)
    end
  end
end

require 'resque'
require 'em-synchrony/em-redis'

module EM::Resque
  extend Resque
  def redis=(server)
    case server
    when String
      if server =~ /redis\:\/\//
        host, port = server.split('/', 3).last.split(':')
        redis = EM::Protocols::Redis.connect(:host => server, :thread_safe => true)
      else
        server, namespace = server.split('/', 2)
        host, port, db = server.split(':')
        redis = EM::Protocols::Redis.new(:host => host, :port => port,
                                         :thread_safe => true, :db => db)
      end
      namespace ||= :resque

      Resque.redis = Redis::Namespace.new(namespace, :redis => redis)
    when Redis::Namespace
      Resque.redis = server
    else
      Resque.redis = Redis::Namespace.new(:resque, :redis => server)
    end
  end
end

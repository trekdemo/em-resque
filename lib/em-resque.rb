require 'resque'
require 'em-synchrony/em-redis'

module EventMachine
  include Resque

  module Resque
    def redis=(server)
      case server
      when String
        if server =~ /redis\:\/\//
          redis = EM::Protocols::Redis.connect(:url => server, :thread_safe => true)
        else
          server, namespace = server.split('/', 2)
          host, port, db = server.split(':')
          redis = EM::Protocols::Redis.new(:host => host, :port => port,
                                           :thread_safe => true, :db => db)
        end
        namespace ||= :resque

        @redis = Redis::Namespace.new(namespace, :redis => redis)
      when Redis::Namespace
        @redis = server
      else
        @redis = Redis::Namespace.new(:resque, :redis => server)
      end
    end
  end
end

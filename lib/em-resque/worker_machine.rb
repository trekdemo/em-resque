require 'em-synchrony'
require 'em-resque'
require 'em-resque/worker'

module EventMachine
  module Resque
    # WorkerMachine is an EventMachine with Resque workers wrapped in Ruby
    # fibers.
    #
    # An instance contains the workers and a system monitor running inside an
    # EventMachine. The monitoring takes care of stopping the machine when all
    # workers are shut down.

    class WorkerMachine
      # Initializes the machine, creates the fibers and workers, traps quit
      # signals and prunes dead workers
      #
      # == Options
      # concurrency::  The number of green threads inside the machine (default 20)
      # interval::     Time in seconds how often the workers check for new work
      #                (default 5)
      # fibers_count:: How many fibers (and workers) to be run inside the
      #                machine (default 1)
      # queues::       Which queues to poll (default all)
      # verbose::      Verbose log output (default false)
      # vverbose::     Even more verbose log output (default false)
      # pidfile::      The file to save the process id number
      def initialize(opts = {})
        @concurrency = opts[:concurrency] || 20
        @interval = opts[:interval] || 5
        @fibers_count = opts[:fibers] || 1
        @queues = opts[:queue] || opts[:queues] || '*'
        @verbose = opts[:logging] || opts[:verbose] || false
        @very_verbose = opts[:vverbose] || false
        @pidfile = opts[:pidfile]
        @redis = opts[:redis]

        raise(ArgumentError, "Should have at least one fiber") if @fibers_count.to_i < 1

        build_workers
        build_fibers
        create_pidfile
      end

      # Start the machine and start polling queues.
      def start
        EM.synchrony do
          EM::Resque.redis = redis_instance(@redis)
          prune_dead_workers
          trap_signals
          @fibers.each(&:resume)
          system_monitor.resume
        end
      end

      # Stop the machine.
      def stop
        @workers.each(&:shutdown)
        File.delete(@pidfile) if @pidfile
      end

      def fibers
        @fibers || []
      end

      def workers
        @workers || []
      end

      private

      # Builds the workers to poll the given queues.
      def build_workers
        queues = @queues.to_s.split(',')

        @workers = (1..@fibers_count.to_i).map do
          worker = EM::Resque::Worker.new(*queues)
          worker.verbose = @verbose
          worker.very_verbose = @very_verbose

          worker
        end
      end

      # Builds the fibers to contain the built workers.
      def build_fibers
        @fibers = @workers.map do |worker|
          Fiber.new do
            worker.log "starting async worker #{worker}"
            worker.work(@interval)
          end
        end
      end

      # Traps signals TERM, INT and QUIT to stop the machine.
      def trap_signals
        ['TERM', 'INT', 'QUIT'].each { |signal| trap(signal) { stop } }
      end

      # Deletes worker information from Redis if there's now processes for
      # their pids.
      def prune_dead_workers
        @workers.first.prune_dead_workers if @workers.size > 0
      end

      # Shuts down the machine if all fibers are dead.
      def system_monitor
        Fiber.new do
          loop do
            EM.stop unless fibers.any?(&:alive?)
            EM::Synchrony.sleep 1
          end
        end
      end

      def create_pidfile
        File.open(@pidfile, 'w') { |f| f << Process.pid } if @pidfile
      end

      def redis_instance(server)
        case server
        when String
          if server =~ /redis\:\/\//
            host, port = server.split('/', 3).last.split(':')
            redis = EM::Protocols::Redis.connect(:host => host, :port => port, :thread_safe => true)
          else
            server, namespace = server.split('/', 2)
            host, port, db = server.split(':')
            redis = EM::Protocols::Redis.new(:host => host, :port => port,
                                             :thread_safe => true, :db => db)
          end
          namespace ||= :resque

          Redis::Namespace.new(namespace, :redis => redis)
        when Redis::Namespace
          server
        else
          Redis::Namespace.new(:resque, :redis => server)
        end
      end
    end
  end
end

require 'em-synchrony'
require 'em-resque/worker'

module EventMachine
  module Resque
    class WorkerMachine
      def initialize(opts)
        @concurrency = opts[:concurrency] || 20
        @interval = opts[:interval] || 5
        @fibers_count = opts[:fibers] || 1
        @queues = opts[:queues] || '*'
        @verbose = opts[:verbose] || false
        @very_verbose = opts[:very_verbose] || false
        @pidfile = opts[:pidfile]

        build_workers
        build_fibers
        trap_signals
        prune_dead_workers
      end

      def start
        throw RuntimeError if @fibers.nil?

        EM.synchrony do
          
          @fibers.each(&:resume)
          garbage_collector.resume
        end
      end

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

      def build_workers
        queues = @queues.to_s.split(',')

        @workers = (1..@fibers_count.to_i).map do
          worker = EM::Resque::Worker.new(queues)
          worker.verbose = @verbose
          worker.very_verbose = @very_verbose

          worker
        end
      end

      def build_fibers
        throw RuntimeError if @workers.nil?

        @fibers = @workers.map do |worker|
          Fiber.new do
            worker.log "startng async worker #{worker}"
            worker.work(@interval)
          end
        end
      end

      def trap_signals
        ['TERM', 'INT', 'QUIT'].each do |signal| 
          trap(signal) do 
            stop
          end
        end
      end

      def prune_dead_workers
        @workers.first.prune_dead_workers if @workers.size > 0
      end

      def garbage_collector
        Fiber.new do
          loop do
            EM.stop unless fibers.any?(&:alive?)
            EM::Synchrony.sleep 1
          end
        end
      end
    end
  end
end

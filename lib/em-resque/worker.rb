require 'resque'

module EventMachine
  module Resque
    class Worker < Resque::Worker
      def work(interval = 1)
        interval = Float(interval)
        register_worker

        loop do
          break if shutdown?

          if not paused? and job = reserve
            log "got: #{job.inspect}"
            job.worker = self
            working_on job

            perform(job)

            done_working
          else
            break if interval.zero?
            log! "Sleeping for #{interval} seconds #{self}"
            EM::Synchrony.sleep interval
          end
        end

      ensure
        unregister_worker
      end

      def processed!
        Resque::Stat << "processed"
        Resque::Stat << "processed:#{self}"
        Resque::Stat << "processed_callback"
      end

      def to_s
        "#{super}:#{Fiber.current.object_id}"
      end
    end


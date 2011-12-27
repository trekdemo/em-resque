require 'resque'

# A non-forking version of Resque worker, which handles waiting with
# a non-blocking version of sleep. 
class EventMachine::Resque::Worker < Resque::Worker
  # Start working
  def work(interval)
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

  # Tell Redis we've processed a job.
  def processed!
    Resque::Stat << "processed"
    Resque::Stat << "processed:#{self}"
    Resque::Stat << "processed_#{job['queue']}"
  end

  # The string representation is the same as the id for this worker instance.
  # Can be used with Worker.find
  def to_s
    "#{super}:#{Fiber.current.object_id}"
  end
  alias_method :id, :to_s
end

require 'resque'

# A non-forking version of Resque worker, which handles waiting with
# a non-blocking version of sleep. 
class EventMachine::Resque::Worker < Resque::Worker
  # Overwrite system sleep with the non-blocking version
  def sleep(interval)
    EM::Synchrony.sleep interval
  end
  
  # Be sure we're never forking
  def fork
    nil
  end

  # Simpler startup
  def startup
    register_worker
    @cant_fork = true
    $stdout.sync = true
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

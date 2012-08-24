require 'resque'

# A non-forking version of Resque worker, which handles waiting with
# a non-blocking version of sleep. 
class EventMachine::Resque::Worker < Resque::Worker
  # Overwrite system sleep with the non-blocking version
  def sleep(interval)
    EM::Synchrony.sleep interval
  end

  # Overwrite Resque's #work method to one that ticks through a reactor instead of one that uses EM::Synchrony sleep.
  #
  # The reason I'm not doing that is because when sending push notifications and using 1 fiber, the response from Apple
  # will come after another job has been finished and is generally unreliable. Note that this means that you can't use
  # this worker with more than one fiber.
  def work(interval = 5.0, &block)
    interval = Float(interval)
    $0 = "resque: Starting"
    startup

    work_loop = lambda do
      if shutdown?
        unregister_worker
        EM.stop
        next
      end

      if not paused? and job = reserve
        log "got: #{job.inspect}"
        job.worker = self
        run_hook :before_fork, job
        working_on job

        if @child = fork
          srand # Reseeding
          procline "Forked #{@child} at #{Time.now.to_i}"
          begin
            Process.waitpid(@child)
          rescue SystemCallError
            nil
          end
        else
          unregister_signal_handlers if !@cant_fork && term_child
          procline "Processing #{job.queue} since #{Time.now.to_i}"
          redis.client.reconnect # Don't share connection with parent
          perform(job, &block)
          exit! unless @cant_fork
          EM::Timer.new(interval) do
            EM.next_tick(&work_loop)
          end
        end

        done_working
        @child = nil
      else
        break if interval.zero?
        log! "Sleeping for #{interval} seconds"
        procline paused? ? "Paused" : "Waiting for #{@queues.join(',')}"
        EM::Timer.new(interval) do
          EM.next_tick(&work_loop)
        end
      end
    end
    EM.next_tick(&work_loop)
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

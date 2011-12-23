require 'em-synchrony'

namespace :em_resque do
  task :setup

  desc "Start an async Resque worker"
  task :work => [ :preload, :setup ] do
    require 'em-resque'

    EM.synchrony do
      concurrency = ENV['CONCURRENCY'] || 20

      if defined?(Rails) && Rails.respond_to?(:application)
        # Rails 3
        Rails.application.eager_load!
      elsif defined?(Rails::Initializer)
        # Rails 2.3
        $rails_rake_task = false
        Rails::Initializer.run :load_application_classes
      end

      queues = (ENV['QUEUES'] || ENV['QUEUE']).to_s.split(',')
      fibers_count = (ENV['FIBERS'].to_i || 1)

      fibers = []

      # Setup the workers
      workers = (1..fibers_count).map do
        worker = EventMachine::Resque::Worker.new(*queues)
        worker.verbose = ENV['LOGGING'] || ENV['VERBOSE']
        worker.very_verbose = ENV['VVERBOSE']

        worker
      end

      # Gather the workers in fibers
      fibers = workers.map do |worker|
        Fiber.new do
          worker.log "Starting async worker #{worker}"
          worker.work(interval)
        end
      end

      # Trap signals and kill workers gracefully on exit
      ['TERM', 'INT', 'QUIT'].each do |signal| 
        trap(signal) do 
          workers.each(&:shutdown) 
          File.delete(ENV['PIDFILE']) if ENV['PIDFILE']
        end
      end

      # Garbage collection
      workers.first.prune_dead_workers

      # PIDFILE for capper
      if ENV['PIDFILE']
        File.open(ENV['PIDFILE'], 'w') { |f| f << workers.first.pid }
      end

      if ENV['BACKGROUND']
        unless Process.respond_to?('daemon')
            abort "env var BACKGROUND is set, which requires ruby >= 1.9"
        end
        Process.daemon(true)
      end

      # Start the worker engine in 3, 2, 1...
      fibers.each(&:resume)

      # Stop the engine if there's no fibers alive
      Fiber.new {
        loop do
          EM.stop unless fibers.any?(&:alive?)
          EM::Synchrony.sleep 1
        end
      }.resume
    end
  end

  # Preload app files if this is Rails
  task :preload => :setup do
    if defined?(Rails) && Rails.respond_to?(:application)
      # Rails 3
      Rails.application.eager_load!
    elsif defined?(Rails::Initializer)
      # Rails 2.3
      $rails_rake_task = false
      Rails::Initializer.run :load_application_classes
    end
  end
end

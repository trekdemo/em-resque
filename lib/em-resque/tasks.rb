require 'em-synchrony'
require 'em-resque/worker_machine'

namespace :em_resque do
  task :setup

  desc "Start an async Resque worker"
  task :work => [ :preload, :setup ] do
    require 'em-resque'

    machine = EM::Resque::WorkerMachine.new(:concurrency => ENV['CONCURRENCY'],
                                            :interval => ENV['INTERVAL'],
                                            :fibers => ENV['FIBERS'],
                                            :queues => ENV['QUEUE'] || ENV['QUEUES'],
                                            :verbose => ENV['LOGGING'] || ENV['VERBOSE'],
                                            :very_verbose => ENV['VVERBOSE'],
                                            :pidfile => ENV['PIDFILE'])

    machine.start
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

require 'em-synchrony'
require 'em-resque/worker_machine'

namespace :em_resque do
  task :setup

  desc "Start an async Resque worker"
  task :work => [ :preload, :setup ] do
    require 'em-resque'

    integer_keys = %w(CONCURRENCY INTERVAL FIBERS)
    string_keys = %w(QUEUE QUEUES PIDFILE)
    bool_keys = %w(LOGGING VERBOSE VVERBOSE)

    opts = ENV.reduce({}) do |acc, (k, v)|
      acc = acc.merge(k.downcase.to_sym => v.to_i) if integer_keys.any?{|ik| ik == k}
      acc = acc.merge(k.downcase.to_sym => v.to_s) if string_keys.any?{|sk| sk == k}
      acc = acc.merge(k.downcase.to_sym => v == '1' || v.downcase == 'true') if bool_keys.any?{|bk| bk == k}
      acc
    end

    machine = EM::Resque::WorkerMachine.new(opts)

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

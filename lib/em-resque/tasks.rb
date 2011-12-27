require 'em-synchrony'
require 'em-resque/worker_machine'
require 'em-resque/task_helper'

namespace :em_resque do
  task :setup

  desc "Start an async Resque worker"
  task :work => [ :setup ] do
    require 'em-resque'

    EM::Resque::WorkerMachine.new(TaskHelper.parse_opts_from_env).start
  end
end

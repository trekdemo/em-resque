require './lib/em-resque/worker_machine.rb'
require './lib/em-resque/task_helper.rb'

EM::Resque::WorkerMachine.new(TaskHelper.parse_opts_from_env).start

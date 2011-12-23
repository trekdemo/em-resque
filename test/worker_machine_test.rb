require 'test_helper'
require 'em-resque/worker_machine'

context 'WorkerMachine' do
  test 'should initialize itself' do
    machine = EM::Resque::WorkerMachine.new

    assert_equal 1, machine.fibers.count
    assert_equal 1, machine.workers.count
    assert_equal Fiber, machine.fibers.first.class
    assert_equal EM::Resque::Worker, machine.workers.first.class
  end
end

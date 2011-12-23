require 'test_helper'
require 'em-resque/worker'

context "Worker" do
  setup do
    EM::Resque.redis.flushall
  end

  test "processes jobs" do
    EM.synchrony do
      EM::Resque.enqueue(TestJob, 420, 'foo')
      worker = EM::Resque::Worker.new('*')
      worker.work(0)

      assert_equal 1, EM::Resque.info[:processed]

      worker.shutdown!
      EM.stop
    end
  end

  test "fails bad jobs" do
    EM.synchrony do
      EM::Resque.enqueue(FailJob, 420, "foo")
      worker = EM::Resque::Worker.new('*')
      worker.work(0)

      assert_equal 1, Resque::Failure.count
      worker.shutdown!
      EM.stop
    end
  end
end

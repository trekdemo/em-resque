require 'test_helper'

context "Resque" do
  setup do
    EM::Resque.redis.flushall
  end

  test "can put jobs to a queue" do
    assert EM::Resque.enqueue(TestJob, 420, 'foo')
  end

  test "can read jobs from a queue" do
    EM::Resque.enqueue(TestJob, 420, 'foo')

    job = EM::Resque.reserve(:jobs)

    assert_equal TestJob, job.payload_class
    assert_equal 420, job.args[0]
    assert_equal 'foo', job.args[1]
  end
end

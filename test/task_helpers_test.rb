require 'test_helper'
require 'em-resque/task_helper'

context "TaskHelper" do
  setup do
    ENV['CONCURRENCY'] = '20'
    ENV['INTERVAL'] = '5'
    ENV['FIBERS'] = '5'
    ENV['QUEUE'] = 'foo'
    ENV['QUEUES'] = 'foo, bar'
    ENV['PIDFILE'] = '/foo/bar'
    ENV['LOGGING'] = '1'
    ENV['VERBOSE'] = 'true'
    ENV['VVERBOSE'] = 'false'

    @valid_opts = {
      :concurrency => ENV['CONCURRENCY'].to_i,
      :interval => ENV['INTERVAL'].to_i,
      :fibers => ENV['FIBERS'].to_i,
      :queue => ENV['QUEUE'],
      :queues => ENV['QUEUES'],
      :pidfile => ENV['PIDFILE'],
      :logging => true,
      :verbose => true,
      :vverbose => false }
  end

  test "can parse all parameters correctly" do
    opts = TaskHelper.parse_opts_from_env
    @valid_opts.each {|k,v| assert_equal v, opts[k]}
  end
end

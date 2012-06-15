require "fileutils"
require "open4"
require "net/http"
require "stringio"

include FileUtils

JETPACK_TEST_MODE = true

def x(cmd)
  stdout = StringIO.new
  stderr = StringIO.new
  result = Open4::spawn("sh -c \"#{cmd}\"", 'raise' => false, 'quiet' => true, 'stdout' => stdout, 'stderr' => stderr)
  exitstatus = result ? result.exitstatus : nil
  {:exitstatus => exitstatus, :stdout => stdout.string, :stderr => stderr.string}
end

def x!(cmd)
  result = x(cmd)
  raise "#{cmd} failed: #{result[:stderr]}" unless result[:exitstatus] == 0
  return result
end

def run_app(app, check_port, env={'RAILS_ENV' => 'development'})
  jetty_pid = Process.spawn(env, 'java', '-jar', 'start.jar', {:chdir => "#{app}/vendor/jetty"})
  start_time = Time.now
  loop do
    begin
      TCPSocket.open("localhost", check_port)
      return jetty_pid
    rescue Errno::ECONNREFUSED
      raise "it's taking too long to start the server, something might be wrong" if Time.now - start_time > 60
      sleep 0.1
    end
  end
end

def replace_remote_references_with_local_mirror(project_dir)
  contents = File.read("#{project_dir}/config/jetpack.yml")
  contents.gsub!("http://jruby.org.s3.amazonaws.com/downloads/1.6.7/jruby-complete-1.6.7.jar",
                 "file://#{File.expand_path('spec/local_mirror')}/jruby-complete-1.6.7.jar")
  contents.gsub!("http://repo1.maven.org/maven2/org/mortbay/jetty/jetty-hightide/8.1.3.v20120416/jetty-hightide-8.1.3.v20120416.zip",
                 "file://#{File.expand_path('spec/local_mirror')}/jetty-hightide-8.1.3.v20120416.zip")
  contents.gsub!("http://repo1.maven.org/maven2/org/jruby/rack/jruby-rack/1.1.5/jruby-rack-1.1.5.jar",
                 "file://#{File.expand_path('spec/local_mirror')}/jruby-rack-1.1.5.jar")
  File.open("#{project_dir}/config/jetpack.yml", "w"){|f|f<<contents}
end

real_tmp_dir = nil
FileUtils.cd("/tmp") { real_tmp_dir = FileUtils.pwd } #because on osx it's really /private/tmp
TEST_ROOT =  File.absolute_path("#{real_tmp_dir}/jetpack_test_root")

def reset
  FileUtils.rm_rf(TEST_ROOT)
  FileUtils.mkdir_p(TEST_ROOT)
end

RSpec.configure do |config|
  config.after(:all) do
    reset
  end
end

require 'thor'
require 'flatware/pids'
module Flatware
  class CLI < Thor

    def self.processors
      @processors ||= ProcessorInfo.count
    end

    def self.worker_option
      method_option :workers, aliases: "-w", type: :numeric, default: processors, desc: "Number of concurent processes to run"
    end

    class_option :log, aliases: "-l", type: :boolean, desc: "Print debug messages to $stderr"

    worker_option
    desc "fan [COMMAND]", "executes the given job on all of the workers"
    def fan(*command)
      Flatware.verbose = options[:log]

      command = command.join(" ")
      puts "Running '#{command}' on #{workers} workers"

      workers.times do |i|
        fork do
          exec({"TEST_ENV_NUMBER" => i.to_s}, command)
        end
      end
      Process.waitall
    end

    desc "clear", "kills all flatware processes"
    def clear
      (Flatware.pids - [$$]).each do |pid|
        Process.kill 6, pid
      end
    end

    private

    def start_sink(jobs:, workers:, formatter:)
     $0 = 'flatware sink'
      Process.setpgrp
      passed = Sink.start_server jobs: jobs, formatter: Flatware::Broadcaster.new([formatter]), sink: options['sink-endpoint'], dispatch: options['dispatch-endpoint'], worker_count: workers
      exit passed ? 0 : 1
    end

    def log(*args)
      Flatware.log(*args)
    end

    def workers
      options[:workers]
    end
  end
end

flatware_gems = Gem.loaded_specs.keys.grep(/^flatware-/)

if flatware_gems.count > 0
  flatware_gems.each(&method(:require))
else
  puts "The flatware gem is a dependency of flatware runners for rspec and cucumber.  Try adding flatware-rspec or flatware-cucumber to your Gemfile."
end

# frozen_string_literal: true

require 'rubygems'
require 'bundler'
require 'bundler/audit'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc 'build the docs'
YARD::Rake::YardocTask.new

namespace :bundle do
  desc 'Checks for dependencies with security problems in either Gemfile.lock or the lock file for BUNDLE_GEMFILE'
  task :audit do
    require 'bundler/audit/cli'

    lockfile = if ENV['BUNDLE_GEMFILE']
                 File.basename("#{ENV['BUNDLE_GEMFILE']}.lock")
               else
                 'Gemfile.lock'
               end

    Bundler::Audit::CLI.start ['check', '--gemfile-lock', lockfile]
  end
end

if ENV['FTP']
  # jruby and truffleruby have issues executing rubocop reliably, so provide a hook for bypassing rubocop
  task default: %i[spec bundle:audit]
else
  # if you didn't ask for us to skip rubocop, include it
  task default: %i[spec rubocop bundle:audit]
end

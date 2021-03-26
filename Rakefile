# frozen_string_literal: true

require 'rubygems'
require 'bundler'
require 'bundler/audit/task'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

Bundler::Audit::Task.new
RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

desc 'build the docs'
YARD::Rake::YardocTask.new

task default: %i[spec rubocop bundle:audit]

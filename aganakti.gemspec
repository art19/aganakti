# frozen_string_literal: true

require_relative 'lib/aganakti/version'

Gem::Specification.new do |spec|
  spec.name          = 'aganakti'
  spec.version       = Aganakti::VERSION
  spec.authors       = ['Keith Gable']
  spec.email         = ['keith@art19.com']

  spec.summary       = 'Ruby client for Apache Druid SQL'
  spec.description   = <<~DESCRIPTION
    Aganakti (ᎠᎦᎾᎦᏘ) is a client for performing queries against Apache Druid SQL and Imply. It is designed to be fast, simple to use, thread safe, support multiple Druid servers,
    and to work just like `ActiveRecord::Base.exec_query`. Currently, we depend on ActiveRecord for `ActiveRecord::Result`, but there are no other Rails requirements. This allows
    it to have wide Rails compatibility.
  DESCRIPTION
  spec.homepage      = 'https://www.github.com/art19/aganakti'
  spec.license       = 'MIT'

  spec.required_ruby_version = Gem::Requirement.new('>= 2.5.0')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://www.github.com/art19/aganakti.git'
  spec.metadata['changelog_uri'] = 'https://www.github.com/art19/aganakti/releases'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features|\..*)/}) }
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord',    '>= 5.1'
  spec.add_dependency 'activesupport',   '>= 5.1'
  spec.add_dependency 'concurrent-ruby', '>= 1.1.8'
  spec.add_dependency 'oj',              '>= 3.11.3'
  spec.add_dependency 'typhoeus',        '>= 1.4.0'

  spec.add_development_dependency 'bundler-audit', '~> 0.8.0'
  spec.add_development_dependency 'json',          '~> 2.5.1' # this is a stdgem now and is needed by SimpleCov which doesn't pull it in
  spec.add_development_dependency 'rake',          '~> 13.0'
  spec.add_development_dependency 'rdoc',          '~> 6.3.0' # YARD requirement
  spec.add_development_dependency 'redcarpet',     '~> 3.5.1' # YARD requirement
  spec.add_development_dependency 'rspec',         '~> 3.0'
  spec.add_development_dependency 'rspec-mocks',   '~> 3.10'
  spec.add_development_dependency 'rubocop',       '~> 1.7'
  spec.add_development_dependency 'rubocop-rake',  '~> 0.5.1'
  spec.add_development_dependency 'rubocop-rspec', '~> 2.2.0'
  spec.add_development_dependency 'simplecov',     '~> 0.21.2'
  spec.add_development_dependency 'solargraph',    '~> 0.40.4'
  spec.add_development_dependency 'stub_server',   '~> 0.5.0'
  spec.add_development_dependency 'webrick',       '~> 1.7.0'
  spec.add_development_dependency 'yard',          '~> 0.9.26'
end

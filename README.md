# Aganakti (ᎠᎦᎾᎦᏘ) - Ruby client for Apache Druid SQL

[![Maintainability](https://api.codeclimate.com/v1/badges/2e54ebd1fc6ff0b8f12b/maintainability)](https://codeclimate.com/github/art19/aganakti/maintainability) [![Test Coverage](https://api.codeclimate.com/v1/badges/2e54ebd1fc6ff0b8f12b/test_coverage)](https://codeclimate.com/github/art19/aganakti/test_coverage)

Aganakti (ᎠᎦᎾᎦᏘ) is a client for performing queries against Apache Druid SQL and Imply. It is designed to be fast, simple to use, thread safe, support multiple Druid servers, and to work just like `ActiveRecord::Base.exec_query`. Currently, we depend on ActiveRecord for `ActiveRecord::Result`, but there are no other Rails requirements. This allows it to have wide Rails compatibility.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'aganakti'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install aganakti

## Usage

```ruby
client = Aganakti.new('http://user:pass@druidserver/druid/v2/sql/', user_agent_prefix: 'your-rails-app/1.0 (+http://www.example.com/)')

# Fluent interface allows modifying the query with a fluent interface before it executes
result = client.query('SELECT * FROM sys.servers')
result = client.query('SELECT * FROM sys.tasks').in_time_zone('America/Los_Angeles')
result = client.query('SELECT MIN(bar) FROM datasource WHERE dim_id = ?', id)
result = client.query('SELECT foo, COUNT(DISTINCT bar) FROM datasource GROUP BY foo').with_approximate_count_distinct
result = client.query('SELECT foo, COUNT(DISTINCT bar) FROM datasource GROUP BY foo').without_approximate_count_distinct
result = client.query('SELECT foo, COUNT(*) FROM datasource GROUP BY foo ORDER BY 2 DESC LIMIT 10').with_approximate_top_n
result = client.query('SELECT foo, COUNT(*) FROM datasource GROUP BY foo ORDER BY 2 DESC LIMIT 10').without_approximate_top_n
result = client.query('SELECT MAX(foo) FROM datasource').result # if you need to force the query to execute for some reason instead of doing so when enumerated

# Result wraps an ActiveRecord::Result, so you can use it just like you'd expect
result.each do |row|
  puts "#{row['foo']}: #{row['bar']}"
end

result.rows.map(&:last).sum
```

## Compatibility

This gem officially supports Ruby 2.5, 2.6, 2.7, and 3.0 on aarch64 and x86_64, with Rails version 5.1, 5.2, 6.0, or 6.1. The test suite additionally tests the ppc64le and s390x architectures, which could have official support if someone were using one of these architectures in production and could confirm it performs acceptably. Please file bugs if this gem does not work for you on any of these architecture, Ruby, or Rails combinations, as we would love to have all of these officially supported.

JRuby is unsupported because we rely on Oj, a C extension, and JRuby does not support C extensions. A PR that added support for a Java-compatible JSON stream parser would be entertained, though if you're running on JRuby, you would likely [prefer to use the Druid/Avatica JDBC driver](https://druid.apache.org/docs/latest/querying/sql.html#jdbc) instead.

TruffleRuby passes the test suite with Rails 6.0 and 6.1, but does not pass in 5.x, where it crashes instead. This is probably a TruffleRuby bug, as it crashes inside the WEBrick server that the test suite sets up to make sure the HTTP traffic flows as expected. I have no idea why the Rails version would have anything to do with it, but perhaps the Rails 6 switch to Zeitwerk for autoloading has something to it. If you want to get this working, PRs are accepted.

Rubinius is not supported, and due to the differing philosophy between its developer and Ruby, it is unlikely that this gem could be made compatible without checks specific to Rubinius or Ruby language level degradation. If you really need this gem to work there and have a PR which doesn't introduce special cases, we would entertain adding support for it.

## Project Name

The name of the project, Aganakti, is one way of saying doctor in the Cherokee language. I chose it because I am Cherokee and thought doctor was a good translation of druid into the language. As Cherokee is polysynthetic, there are several different ways of saying doctor, but I landed on aganakti because it is pronounced very closely to how you might intuitively pronounce it in English. Like the Japanese kana, Cherokee is written and pronounced using a syllabary, rather than an alphabet. Taking the syllables ᎠᎦᎾᎦᏘ and writing them out phonetically, you have a-ga-na-ga-ti. The vowel "a" is pronounced like the a in "father" and the vowel "i" is pronounced like the ee in "seek". The consonants in this case are pronounced like you would expect in English, but g is close to the k in "skate". Now you've got something that you would in English pronounce as "ah gah nah gah tee". If you say it fast, then you end up with something close to "ah gah knock tee", and so that is how it's pronounced and usually written. [The Cherokee Nation of Oklahoma has a recording of someone slowly saying the word if you want to hear a native speaker say it](https://data.cherokee.org/Cherokee/LexiconSoundFiles/Doctor.mp3), though they've left off the optional "a-" prefix.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org). _This gem is currently not published to RubyGems, so this will have no effect._

### Building and Publishing @ ART19 (until we publish to RubyGems)

This gem is currently deployed to GitHub packages, while we test it with a less broad audience in production.

Follow the [GitHub Packages Guide](https://help.github.com/en/github/managing-packages-with-github-packages/configuring-rubygems-for-use-with-github-packages) to set up your system for this. You will end up creating a key in `~/.gem/credentials`, probably named `github`. Once you've done that, you can `GEM_PUSH_KEY=whatever bundle exec rake publish` to publish the gem. Please note that once you "use" a version number on GitHub, it's used forever, so be sure to edit the version number in the app to add `.pre.GIT_SHORT_HASH` to the end if this is a test build (you can use `git rev-parse --short --verify HEAD` to get the Git short hash).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/art19/aganakti. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/art19/aganakti/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Aganakti project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/art19/aganakti/blob/main/CODE_OF_CONDUCT.md).

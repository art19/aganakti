# Aganakti (ᎠᎦᎾᎦᏘ) - Ruby client for Apache Druid SQL

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

## Project Name

The name of the project, Aganakti, is one way of saying doctor in the Cherokee language. I chose it because I am Cherokee and thought doctor was a good translation of druid into the language. As Cherokee is polysynthetic, there are several different ways of saying doctor, but I landed on aganakti because it is pronounced very closely to how you might intuitively pronounce it in English. Like the Japanese kana, Cherokee is written and pronounced using a syllabary, rather than an alphabet. Taking the syllables ᎠᎦᎾᎦᏘ and writing them out phonetically, you have a-ga-na-ga-ti. The vowel "a" is pronounced like the a in "father" and the vowel "i" is pronounced like the ee in "seek". The consonants in this case are pronounced like you would expect in English, but g is close to the k in "skate". Now you've got something that you would in English pronounce as "ah gah nah gah tee". If you say it fast, then you end up with something close to "ah gah knock tee", and so that is how it's pronounced and usually written. [The Cherokee Nation of Oklahoma has a recording of someone slowly saying the word if you want to hear a native speaker say it](https://data.cherokee.org/Cherokee/LexiconSoundFiles/Doctor.mp3), though they've left off the optional "a-" prefix.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/art19/aganakti. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/art19/aganakti/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Aganakti project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/art19/aganakti/blob/main/CODE_OF_CONDUCT.md).

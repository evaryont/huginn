module Agents
  class TwitterUserAgent < Agent
    include TwitterConcern

    cannot_receive_events!

    description <<-MD
      #{twitter_dependencies_missing if dependencies_missing?}
      The TwitterUserAgent follows the timeline of a specified Twitter user.

      To be able to use this Agent you need to authenticate with Twitter in the [Services](/services) section first.

      You must also provide the `username` of the Twitter user to monitor.

      Set `include_retweets` to `false` to not include retweets (default: `true`)

      Set `expected_update_period_in_days` to the maximum amount of time that you'd expect to pass between Events being created by this Agent.

      Set `starting_at` to the date/time (eg. `Mon Jun 02 00:38:12 +0000 2014`) you want to start receiving tweets from (default: agent's `created_at`)
    MD

    event_description <<-MD
      Events are the raw JSON provided by the [Twitter API](https://dev.twitter.com/docs/api/1.1/get/statuses/user_timeline). Should look something like:

          {
             ... every Tweet field, including ...
            "text": "something",
            "user": {
              "name": "Mr. Someone",
              "screen_name": "Someone",
              "location": "Vancouver BC Canada",
              "description":  "...",
              "followers_count": 486,
              "friends_count": 1983,
              "created_at": "Mon Aug 29 23:38:14 +0000 2011",
              "time_zone": "Pacific Time (US & Canada)",
              "statuses_count": 3807,
              "lang": "en"
            },
            "retweet_count": 0,
            "entities": ...
            "lang": "en"
          }
    MD

    default_schedule "every_1h"

    def working?
      event_created_within?(interpolated['expected_update_period_in_days']) && !recent_error_logs?
    end

    def default_options
      {
        'username' => 'tectonic',
        'include_retweets' => 'true',
        'expected_update_period_in_days' => '2'
      }
    end

    def validate_options
      errors.add(:base, "username is required") unless options['username'].present?
      errors.add(:base, "expected_update_period_in_days is required") unless options['expected_update_period_in_days'].present?

      if options[:include_retweets].present? && !%w[true false].include?(options[:include_retweets])
        errors.add(:base, "include_retweets must be a boolean value string (true/false)")
      end

      if options[:starting_at].present?
        Time.parse(options[:starting_at]) rescue errors.add(:base, "Error parsing starting_at")
      end
    end

    def starting_at
      if interpolated[:starting_at].present?
        Time.parse(interpolated[:starting_at]) rescue created_at
      else
        created_at
      end
    end

    def include_retweets?
      interpolated[:include_retweets] != "false"
    end

    def check
      since_id = memory['since_id'] || nil
      opts = {:count => 200, :include_rts => include_retweets?, :exclude_replies => false, :include_entities => true, :contributor_details => true}
      opts.merge! :since_id => since_id unless since_id.nil?

      # http://rdoc.info/gems/twitter/Twitter/REST/Timelines#user_timeline-instance_method
      tweets = twitter.user_timeline(interpolated['username'], opts)

      tweets.each do |tweet|
        if tweet.created_at >= starting_at
          memory['since_id'] = tweet.id if !memory['since_id'] || (tweet.id > memory['since_id'])

          create_event :payload => tweet.attrs
        end
      end

      save!
    end
  end
end

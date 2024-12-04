# frozen_string_literal: true

# app/infrastructure/cache/redis_cache.rb
require 'redis'

module MealDecoder
  module Cache
    # Redis client wrapper
    class Client
      def initialize(config)
        @redis = Redis.new(url: config.REDISCLOUD_URL)
      end

      def keys
        @redis.keys
      end

      def wipe
        deleted = keys
        deleted.each { |key| @redis.del(key) }
        deleted
      end
    end
  end
end

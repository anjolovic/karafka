# frozen_string_literal: true

# When doing work with error, we should slowly increase the attempt count

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.max_messages = 20
  config.license.token = pro_license_token
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:attempts] << coordinator.pause_tracker.attempt

    raise StandardError
  end
end

draw_routes(Consumer)

elements = DT.uuids(100)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:attempts].size >= 20
end

assert_equal [], (1..20).to_a - DT[:attempts], DT[:attempts]

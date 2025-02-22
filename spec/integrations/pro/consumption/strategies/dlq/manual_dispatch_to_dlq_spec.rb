# frozen_string_literal: true

# When having the DLQ defined, we should be able to manually dispatch things to the DLQ and
# continue processing whenever we want.

# We can use this API to manually move stuff to DLQ without raising any errors upon detecting a
# corrupted message.

setup_karafka do |config|
  config.license.token = pro_license_token
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      dispatch_to_dlq(message) if message.offset.zero?
    end
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 1_000)
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

elements = DT.uuids(10)
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[:broken].size >= 1
end

assert_equal DT[:broken].size, 1, DT.data

broken = DT[:broken].first

assert_equal elements[0], broken.raw_payload, DT.data
assert_equal broken.headers['original_topic'], DT.topic
assert_equal broken.headers['original_partition'].to_i, 0
assert_equal broken.headers['original_offset'].to_i, 0

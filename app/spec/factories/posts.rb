# spec/factories/posts.rb
require "faker"

FactoryBot.define do
  factory :post do
    title  { Faker::Lorem.sentence(word_count: 4) }
    body   { Faker::Lorem.paragraphs(number: 2).join("\n\n") }
    status { "draft" }
  end
end

# frozen_string_literal: true

# db/migrate/001_create_posts.rb

Sequel.migration do
  up do
    create_table :posts do
      primary_key :id
      String  :title,      null: false, size: 255
      String  :body,       null: false, text: true
      String  :status,     null: false, default: "draft", size: 20
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :status
      index :created_at
    end
  end

  down do
    drop_table :posts
  end
end

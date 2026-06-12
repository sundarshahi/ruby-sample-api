# frozen_string_literal: true

# models/post.rb

class Post < Sequel::Model
  plugin :validation_helpers
  plugin :timestamps, update_on_create: true
  plugin :json_serializer

  # ── Validations ─────────────────────────────────────────────────────────────
  def validate
    super
    validates_presence   %i[title body]
    validates_max_length 255, :title
    validates_max_length 10_000, :body
    validates_includes   %w[draft published archived], :status, allow_nil: true
  end

  # ── Scopes ───────────────────────────────────────────────────────────────────
  dataset_module do
    def published  = where(status: "published").order(Sequel.desc(:created_at))
    def recent(n)  = order(Sequel.desc(:created_at)).limit(n)
    def search(q)  = where(Sequel.ilike(:title, "%#{q}%"))
  end

  # ── Serialisation ────────────────────────────────────────────────────────────
  def to_api_hash
    {
      id:         id,
      title:      title,
      body:       body,
      status:     status,
      created_at: created_at&.iso8601,
      updated_at: updated_at&.iso8601
    }
  end
end

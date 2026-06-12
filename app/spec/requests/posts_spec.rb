# spec/requests/health_spec.rb
require "spec_helper"

RSpec.describe "Health endpoints", type: :request do
  describe "GET /health" do
    it "returns 200 with status ok" do
      get "/health"
      expect(last_response.status).to eq 200
      body = Oj.load(last_response.body)
      expect(body["status"]).to eq "ok"
    end
  end

  describe "GET /health/ready" do
    it "returns 200 when DB is connected" do
      get "/health/ready"
      expect(last_response.status).to eq 200
      body = Oj.load(last_response.body)
      expect(body["status"]).to eq "ready"
      expect(body["database"]).to eq "connected"
    end
  end
end

# spec/requests/posts_spec.rb
RSpec.describe "Posts API", type: :request do
  let(:post_attrs) { { title: "Test Post", body: "Hello world", status: "draft" } }

  describe "GET /api/v1/posts" do
    before { Post.create(post_attrs) }

    it "returns paginated list" do
      get "/api/v1/posts"
      expect(last_response.status).to eq 200
      body = Oj.load(last_response.body)
      expect(body["data"]).to be_an(Array)
      expect(body["data"].length).to eq 1
      expect(body["meta"]["total"]).to eq 1
    end
  end

  describe "GET /api/v1/posts/:id" do
    let!(:post) { Post.create(post_attrs) }

    it "returns the post" do
      get "/api/v1/posts/#{post.id}"
      expect(last_response.status).to eq 200
      body = Oj.load(last_response.body)
      expect(body["title"]).to eq "Test Post"
    end

    it "returns 404 for unknown id" do
      get "/api/v1/posts/99999"
      expect(last_response.status).to eq 404
    end
  end

  describe "POST /api/v1/posts" do
    it "creates a post" do
      post "/api/v1/posts",
           Oj.dump(post_attrs),
           "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq 201
      body = Oj.load(last_response.body)
      expect(body["title"]).to eq "Test Post"
      expect(body["id"]).to be_an(Integer)
    end

    it "rejects missing title" do
      post "/api/v1/posts",
           Oj.dump({ body: "no title" }),
           "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq 422
    end
  end

  describe "PATCH /api/v1/posts/:id" do
    let!(:post) { Post.create(post_attrs) }

    it "updates the post" do
      patch "/api/v1/posts/#{post.id}",
            Oj.dump({ status: "published" }),
            "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq 200
      expect(Oj.load(last_response.body)["status"]).to eq "published"
    end
  end

  describe "DELETE /api/v1/posts/:id" do
    let!(:post) { Post.create(post_attrs) }

    it "deletes the post" do
      delete "/api/v1/posts/#{post.id}"
      expect(last_response.status).to eq 204
      expect(Post.with_pk(post.id)).to be_nil
    end
  end
end

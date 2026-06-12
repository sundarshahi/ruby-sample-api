# frozen_string_literal: true

# controllers/posts_controller.rb — full CRUD for Post resource

module PostsController
  PAGE_SIZE = 20

  def self.registered(app)
    app.namespace "/api/v1" do

      # GET /api/v1/posts  — list with pagination + optional search
      get "/posts" do
        page  = [params[:page].to_i,  1].max
        q     = params[:q]&.strip

        dataset = q ? Post.search(q) : Post.order(Sequel.desc(:created_at))
        records = dataset.paginate(page, PAGE_SIZE)

        json(
          data:  records.map(&:to_api_hash),
          meta: {
            page:        page,
            per_page:    PAGE_SIZE,
            total:       records.pagination_record_count,
            total_pages: records.page_count
          }
        )
      end

      # GET /api/v1/posts/:id
      get "/posts/:id" do
        post = Post.with_pk!(params[:id].to_i)
        json post.to_api_hash
      end

      # POST /api/v1/posts
      post "/posts" do
        data = parse_body
        post = Post.create(
          title:  data["title"],
          body:   data["body"],
          status: data.fetch("status", "draft")
        )
        status 201
        json post.to_api_hash
      end

      # PATCH /api/v1/posts/:id
      patch "/posts/:id" do
        post = Post.with_pk!(params[:id].to_i)
        data = parse_body
        post.update(data.slice("title", "body", "status").compact)
        json post.to_api_hash
      end

      # DELETE /api/v1/posts/:id
      delete "/posts/:id" do
        post = Post.with_pk!(params[:id].to_i)
        post.destroy
        status 204
        ""
      end
    end
  end

  private

  def parse_body
    request.body.rewind
    raw = request.body.read
    return {} if raw.empty?

    Oj.load(raw) || {}
  rescue Oj::ParseError
    halt 400, { error: "Invalid JSON body" }.to_json
  end
end

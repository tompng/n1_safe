# Rails N+1 Safe

`.includes(ごちゃごちゃ)`
の代わりに
`.n1_safe`
をつけるだけでN+1クエリを回避してくれる奴


## gemfile
`gem 'n1_safe' github: 'tompng/n1_safe'`

## controller
includesとかはせずにとりあえずn1_safeを付けておく
```ruby
def index
  @posts = Post.all.n1_safe
  #Post load (X.Xms) SELECT "posts".* FROM "posts"
end
def show
  @post = Post.find params[:id]
  #Post load (X.Xms) SELECT "posts".* FROM "posts" WHERE "posts"."id" = 1 LIMIT 1
end
```

## view
なにも考えずにeachとかまわしまくると、必要になった時にまとめてN+1を回避しつつloadされる感じ
```erb
<% @posts.each do |post| %>
  <h1><%= post.title %> | <%= post.user.name %></h1>
  <p><%= post.body %></p>
  <% post.comments.each do |comment| %>
    <%= comment.user.name %>
    <%= comment.text %>
    <%= comment.stars.count %>
  <% end %>
<% end %>
<!--
#User load (X.Xms) SELECT "users".* FROM "users" WHERE "users"."id" IN (1,3)
#Comment load (X.Xms) SELECT "comments".* FROM "comments" WHERE "comments"."post_id" IN (1,2)
#User load (X.Xms) SELECT "users".* FROM "users" WHERE "users"."id" IN (3,4,5)
# (X.Xms) SELECT COUNT(*) AS count_all, coment_id as comment_id FROM "stars" WHERE "stars"."comment_id" IN (1,2,3,4,7,8) GROUP BY comment_id
-->
```

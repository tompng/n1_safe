class Blog < ActiveRecord::Base
  belongs_to :owner, class: User
  has_many :posts
  has_many :draft_posts, ->{draft}, class: Post
  has_many :published_posts, ->{published}, class: Post
  has_many :favs, as: :target
  has_many :through_comments, class: Comment, through: :posts, source: :comments
  has_many :faved_users, class: User, through: :favs, source: :user
end

class User < ActiveRecord::Base
  has_many :blogs, foreign_key: :owner_id
  has_many :posts, foreign_key: :author_id
  has_many :trashes, primary_key: :another_id, foreign_key: :user_another_id
  has_many :favs
  has_many :fav_posts, class: Post, through: :favs
  has_many :fav_blog, class: Blog, through: :favs
  before_validation{
    self.another_id ||= SecureRandom.hex
  }
end

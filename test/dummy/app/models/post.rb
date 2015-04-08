class Post < ActiveRecord::Base
  belongs_to :blog
  belongs_to :author, class: User
  scope :published, ->{where published: true}
  scope :draft, ->{where published: false}
  has_many :favs, as: :target
  has_many :faved_users, class: User, through: :favs
end

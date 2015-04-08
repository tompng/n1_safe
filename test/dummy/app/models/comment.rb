class Comment < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
  has_many :favs, as: :target
  has_many :faved_users, class: User, through: :favs, source: :user
end

class Trash < ActiveRecord::Base
  belongs_to :user, primary_key: :another_id, foreign_key: :user_another_id
end

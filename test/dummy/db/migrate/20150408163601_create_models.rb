class CreateModels < ActiveRecord::Migration
  def change
    create_table :blogs do |t|
      t.references :owner
    end

    create_table :posts do |t|
      t.references :blog
      t.references :author
      t.boolean :published
    end

    create_table :comments do |t|
      t.references :post
      t.references :user
    end

    create_table :favs do |t|
      t.string :target_type
      t.references :target
      t.references :user
    end

    create_table :users do |t|
      t.string :type
      t.string :another_id
    end

    create_table :trashes do |t|
      t.string :user_another_id
    end
  end
end

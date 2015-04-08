class CreateModels < ActiveRecord::Migration
  def change
    create_table :blogs do |t|
      t.references :owner
    end
    add_index :blogs, :owner_id

    create_table :posts do |t|
      t.references :blog
      t.references :author
      t.boolean :published
    end
    add_index :posts, :blog_id
    add_index :posts, :author_id

    create_table :comments do |t|
      t.references :post
      t.references :user
    end
    add_index :comments, :post_id
    add_index :comments, :user_id

    create_table :favs do |t|
      t.string :target_type
      t.references :target
      t.references :user
    end
    add_index :favs, [:target_type, :target_id]
    add_index :favs, :user_id

    create_table :users do |t|
      t.string :type
      t.string :another_id
    end
    add_index :users, :another_id

    create_table :trashes do |t|
      t.string :user_another_id
    end
    add_index :trashes, :user_another_id
  end
end

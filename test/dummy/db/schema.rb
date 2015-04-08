# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150408163601) do

  create_table "blogs", force: :cascade do |t|
    t.integer "owner_id"
  end

  create_table "comments", force: :cascade do |t|
    t.integer "post_id"
    t.integer "user_id"
  end

  create_table "favs", force: :cascade do |t|
    t.string  "target_type"
    t.integer "target_id"
    t.integer "user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.integer "blog_id"
    t.integer "author_id"
    t.boolean "published"
  end

  create_table "trashes", force: :cascade do |t|
    t.string "user_another_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "type"
    t.string "another_id"
  end

end

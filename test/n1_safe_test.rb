require 'test_helper'

class N1SafeTest < ActiveSupport::TestCase
  def prepare
    10.times{User.create}
    10.times{AdminUser.create}
    10.times{SuperUser.create}
    users = User.all.to_a
    blogs = 5.times.map{Blog.create owner: users.sample}
    posts = 20.times.map{blogs.sample.posts.create author: users.sample, published: [true,false].sample}
    comments = 80.times.map{posts.sample.comments.create user: users.sample}
    10.times{blogs.sample.favs.create user: users.sample}
    40.times{posts.sample.favs.create user: users.sample}
    160.times{comments.sample.favs.create user: users.sample}
    60.times{users.sample.trashes.create}
  end


  def self.include_testcases
    {
      model: [
        ->{Blog.first},
        ->(blog){
          blog.posts.flat_map(&:comments)
        }
      ],
      scope: [
        ->{Blog.limit(3)},
        ->(blogs){
          blogs.flat_map(&:draft_posts).flat_map(&:comments)
        }
      ],
      polymorphic_and_sti: [
        ->{Blog.limit(2)},
        ->(blogs){
          blogs.flat_map(&:posts).flat_map(&:favs).flat_map(&:user).flat_map(&:blogs)
        }
      ],
      through_and_primarykey: [
        ->{Trash.all},
        ->(trashes){
          trashes.flat_map(&:user).flat_map(&:blogs).flat_map(&:faved_users).flat_map(&:trashes)
        }
      ]
    }
  end

  def self.count_testcases
    {
      all: [
        ->{Blog.all},
        ->(blogs){
          blogs.map{|blog|
            [
              blog.draft_posts.count,
              blog.posts.map{|p|[p.comments.count, p.faved_users.count]},
              blog.favs.count,
              blog.owner.trashes.count,
              blog.through_comments.count
            ]
          }
        }
      ]
    }
  end

  include_testcases.each do |name, cond|
    target, proc = cond
    test name.to_s do
      prepare
      before = proc.call target.call
      after = proc.call target.call.n1_safe
      assert_equal before, after
      assert_sql_count(:not_implemented)
    end
  end

  count_testcases.each do |name, cond|
    target, proc = cond
    test name.to_s do
      prepare
      t1=Time.now
      before = proc.call target.call
      t2=Time.now
      after = proc.call target.call.n1_safe
      t3=Time.now
      assert_equal before, after
      assert_sql_count(:not_implemented)
      assert_count_group_by_query(:not_implemented)
    end
  end

end

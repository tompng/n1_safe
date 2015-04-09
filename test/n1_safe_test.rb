require 'test_helper'

module SQLCounts
  module M
    def exec_query *args
      SQLCounts.increment_count
      SQLCounts.log args
      super
    end
  end
  def self.log str
    @logs << str.join(' ') if @logs
  end
  def self.increment_count
    @count = count + 1
  end
  def self.count
    @count ||= 0
    return @count unless block_given?
    @logs = []
    before = self.count
    out = yield
    after = self.count
    logs = @logs
    @logs = nil
    [after - before, out, logs]
  end
  ActiveRecord::Base.connection.extend M
end

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
          blog.posts.flat_map(&:comments).flat_map(&:user)
        },
        4
      ],
      scope: [
        ->{Blog.limit(3)},
        ->(blogs){
          blogs.flat_map(&:draft_posts).flat_map(&:comments)
        },
        3
      ],
      polymorphic_and_sti: [
        ->{Blog.limit(2)},
        ->(blogs){
          blogs.flat_map(&:posts).flat_map(&:favs).flat_map(&:user).flat_map(&:blogs)
        },
        5
      ],
      through_and_primarykey: [
        ->{Trash.all},
        ->(trashes){
          trashes.flat_map(&:user).flat_map(&:blogs).flat_map{|b|b.faved_users.sort_by(&:inspect)}.flat_map(&:trashes)
        },
        6
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
              blog.posts.map{|p|p.author.trashes.count},
              blog.through_comments.count
            ]
          }
        },
        12,
        6
      ]
    }
  end

  include_testcases.each do |name, cond|
    target, proc, expected_count = cond
    test name.to_s do
      prepare
      before_count, before = SQLCounts.count{proc.call target.call}
      after_count, after = SQLCounts.count{proc.call target.call.n1_safe}
      assert_equal before, after
      assert_operator before_count, :>=, expected_count*2
      assert_operator after_count, :==, expected_count
    end
  end

  count_testcases.each do |name, cond|
    target, proc, expected_count, expected_groupbys = cond
    test name.to_s do
      prepare
      before_count, before = SQLCounts.count{proc.call target.call}
      after_count, after, sqls = SQLCounts.count{proc.call target.call.n1_safe}
      assert_equal before, after
      assert_operator before_count, :>=, expected_count*2
      assert_operator after_count, :==, expected_count
      assert_operator sqls.grep(/GROUP BY/).count, :==, expected_groupbys
      assert_operator sqls.grep(/COUNT/).count, :==, expected_groupbys
    end
  end

end

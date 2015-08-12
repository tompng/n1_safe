require_relative './test_helper'

module SQLCapture
  module M
    def exec_query *args
      SQLCapture.log args.join(' ')
      super
    end
  end
  def self.log str
    @logs << str if @logs
  end
  def self.capture
    @logs = []
    out = yield
    logs = @logs
    @logs = nil
    [logs, out]
  end
  ActiveRecord::Base.connection.extend M
end

class N1SafeTest < ActiveSupport::TestCase
  def prepare
    5.times{User.create}
    5.times{AdminUser.create}
    5.times{SuperUser.create}
    users = User.all.to_a
    user_or_nil=->{
      users.sample if rand<0.5
    }
    blogs = 5.times.map{Blog.create owner: users.sample}
    posts = 40.times.map{blogs.sample.posts.create author: user_or_nil[], published: [true,false].sample}
    comments = 80.times.map{posts.sample.comments.create user: user_or_nil[]}
    40.times{blogs.sample.favs.create user: users.sample}
    80.times{posts.sample.favs.create user: users.sample}
    160.times{comments.sample.favs.create user: users.sample}
    60.times{users.sample.trashes.create}
  end

  test('demo'){
    prepare;
    def SQLCapture.log str;puts "\e[1m#{str}\e[m";end
    require 'pry'
    binding.pry
    def SQLCapture.log str;@logs << str if @logs;end
  } if ARGV[0]=='demo'

  def self.include_testcases
    {
      model: [
        ->{Blog.first},
        ->(blog){
          blog.posts.flat_map(&:comments).flat_map(&:favs).flat_map(&:user)
        },
        5
      ],
      has_nil: [
        ->{Comment.all},
        ->(comments){
          comments.map(&:user).compact.flat_map(&:blogs)
        },
        3
      ],
      scope: [
        ->{Blog.limit(3)},
        ->(blogs){
          blogs.flat_map(&:draft_posts).flat_map(&:comments)
        },
        3
      ],
      polymorphic_and_sti: [
        ->{Blog.all},
        ->(blogs){
          blogs.flat_map(&:posts).flat_map(&:favs).flat_map(&:user).flat_map(&:blogs)
        },
        5
      ],
      inverse_polymorphic: [
        ->{Blog.all},
        ->(blogs){
          blogs.map(&:owner).flat_map(&:favs).map{|fav|
            case fav.target
            when Comment
              fav.target.user
            when Post
              fav.target.author
            when Blog
              fav.target.owner
            else
              raise 'error'
            end
          }
        },
        9
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
              blog.posts.map{|p|p.author.trashes.count if p.author},
              blog.through_comments.count
            ]
          }
        },
        11,
        8
      ],
      inverse_polymorphic: [
        ->{Blog.all},
        ->(blogs){
          blogs.map(&:owner).flat_map(&:favs).map(&:target).map{|target|
            case target
            when Post
              target.comments.count
            when Comment
              target.user.favs.count if target.user
            when Blog
              target.posts.count
            else
              raise 'error'
            end
          }
        },
        12,
        5
      ]
    }
  end

  include_testcases.each do |name, cond|
    target, proc, expected_count = cond
    test name.to_s do
      prepare
      before_sqls, before = SQLCapture.capture{proc.call target.call}
      after_sqls, after = SQLCapture.capture{proc.call target.call.n1_safe}
      assert_equal before, after
      assert_operator before_sqls.size, :>=, expected_count*2
      assert_operator after_sqls.size, :==, expected_count
    end
  end

  count_testcases.each do |name, cond|
    target, proc, expected_count, expected_groupbys = cond
    test "count_#{name}" do
      prepare
      before_sqls, before = SQLCapture.capture{proc.call target.call}
      after_sqls, after = SQLCapture.capture{proc.call target.call.n1_safe}
      assert_equal before, after
      assert_operator before_sqls.size, :>=, expected_count*2
      assert_operator before_sqls.grep(/COUNT/).count, :>=, expected_groupbys*2
      assert_operator [after_sqls.size,
                      after_sqls.grep(/GROUP BY/).count,
                      after_sqls.grep(/COUNT/).count],
                      :==,
                      [expected_count, expected_groupbys, expected_groupbys]
    end
  end

end

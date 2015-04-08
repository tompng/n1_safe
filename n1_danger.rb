##controller
def index
  #includesとかはせずにとりあえずn1_safeを付けておく
  @posts = Post.all.n1_safe
end
#Post load (X.Xms) SELECT "posts".* FROM "posts"

##view
#なにも考えずにeachとかまわしまくると、必要になった時にまとめてN+1を回避しつつloadされる感じ
<% @posts.each do |post| %>
  <h1><%= post.title %> | <%= post.user.name %></h1>
  <p><%= post.body %></p>
  <% post.comments.each do |comment| %>
    <%= comment.user.name %>
    <%= comment.text %>
    <%= comment.stars.count %>
  <% end %>
<% end %>
#User load (X.Xms) SELECT "users".* FROM "users" WHERE "users"."id" IN (1,3)
#Comment load (X.Xms) SELECT "comments".* FROM "comments" WHERE "comments"."post_id" IN (1,2)
#User load (X.Xms) SELECT "users".* FROM "users" WHERE "users"."id" IN (3,4,5)
# (X.Xms) SELECT COUNT(*) AS count_all, coment_id as comment_id FROM "stars" WHERE "stars"."comment_id" IN (1,2,3,4,7,8) GROUP BY comment_id


module N1Safe
  class LazyLoader
    def initialize bases
      @bases = bases
      @cache = {}
      @cache[[]] = bases
      @count_cache = {}
    end

    def self.preloader
      @@preloader ||= ActiveRecord::Associations::Preloader.new
    end

    def count model, path, name
      cache = @count_cache[[path, name]]
      return cache[[model.class, model.id]] if cache
      cache = {}
      all_siblings = @cache[path]
      all_siblings.group_by(&:class).each do |klass, siblings|
        reflection = klass.reflections[name]
        next if reflection.belongs_to?
        next unless reflection.collection?
        next if reflection.through_reflection
        relation = reflection.klass.where reflection.foreign_key => siblings.map(&:id)
        relation = relation.where reflection.type => klass.name if reflection.type
        relation = relation.instance_exec &reflection.scope if reflection.scope
        counts = relation.group(reflection.foreign_key).count
        siblings.each do |sibling|
          cache[[klass, sibling.id]] = counts[sibling.id] || 0
        end
      end
      @count_cache[[path, name]] = cache
      cache[[model.class, model.id]]
    end

    def preload path
      return if @cache[path]
      *parent_path, name = path
      preload parent_path
      parents = @cache[parent_path]
      childs = {}
      LazyLoader.preloader.preload parents, name
      parents.map{|parent|
        child = parent.send(name)
        child = child.to_a if ActiveRecord::Relation === child
        childs[[parent.class, parent.id]] = child if child
      }
      @cache[path] = childs.values.flatten
    end
  end

  class Model < BasicObject
    def initialize root, model, path
      @root = root
      @model = model
      @path = path
    end
    def method_missing name, *args, &block
      reflection = @model.reflections[name]
      if reflection.nil? || args.present? || block
        return @model.send(name, *args, &block)
      end
      if reflection.collection?
        childs = send name
        Relation.new @root, childs, [*@path, name], @model
      else
        @root.preload [*@path, name]
        child = send name
        Model.new @root, child, [*@path, name] if child
      end
    end
  end

  class Relation < BasicObject
    def initialize root, collection, path, parent
      @root = root
      @collection = collection
      @path = path
      @parent = parent
    end

    ::Enumerator.instance_methods.each do |name|
      define_method name do |*args, &block|
        @root.preload @path
        @collection.map{|model|
          Model.new @root, model, (@path||[])
        }.send(name, *args, &block)
      end
    end

    [:count, :size].each do |method|
      define_method method do |*args, &block|
        @collection.send(method, *args, &block) if args.present? || block || @parent.nil?
        *parent_path, name = @path
        @root.count(@parent, parent_path, name) || @collection.send(method, *args, &block)
      end
    end

    def method_missing name, *args, &block
      @collection.send name, *args, &block
    end
  end
end

ActiveRecord::Base.singleton_class.class_eval do
  define_method :n1_safe do
    all.n1_safe
  end
end

ActiveRecord::Base.class_eval do
  define_method :n1_safe do
    root = N1Safe::LazyLoader.new [self]
    N1Safe::Model.new root, self, []
  end
end

ActiveRecord::Relation.class_eval do
  define_method :n1_safe do
    root = N1Safe::LazyLoader.new to_a
    N1Safe::Relation.new root, self, [], nil
  end
end

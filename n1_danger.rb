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
  class NotImplemented < Exception;end
  class LazyLoader
    def initialize bases
      @bases = bases
      @cache = {}
      @cache[[]] = {nil => bases}
      @count_cache = {}
    end

    def count paths, model, name
      path_key = [*paths, name]
      cache_key = conditions_for model, name
      return @cache[path_key][cache_key].try(:size) || 0 if @cache[path_key]
      precount(path_key)[cache_key]
    end

    def precount paths
     return @count_cache[paths] if @count_cache[paths]
      cache = Hash.new(0)
      *parent_paths, name = paths
      parents = preload(parent_paths).values.flatten
      klass_conditions = {}
      conditions = parents.map do |model|
        reflection = model.reflections[name]
        klass, key, value, scope, cond = conditions_for model, name
        next unless klass
        if reflection.through_reflection
          raise NotImplemented
        else
          klass_conditions[[klass, key, scope, cond]]||=[]
          klass_conditions[[klass, key, scope, cond]] << value
        end
      end

      klass_conditions.each do |kkc, values|
        klass, key, scope, cond = kkc
        relation = klass.where(cond).where(key => values)
        relation = relation.instance_eval &scope if scope
        relation.group(key).count.each{|mkey, count|
          cache_key = [klass, key, mkey, scope, cond]
          cache[cache_key] += count
        }
      end
      @count_cache[paths] = cache
      cache
    end

    def load paths, model, name
      child_siblings = preload [*paths, name]
      cache_key = conditions_for model, name
      childs = child_siblings[cache_key] || []
      model.reflections[name].collection? ? childs : childs.first
    end

    def conditions_for model, name
      reflection = model.reflections[name]
      return unless reflection
      if reflection.belongs_to?
        if reflection.polymorphic?
          type = model[reflection.foreign_type]
          id = model[reflection.foreign_key]
          return unless type && id
          [type.constantize, :id, id, reflection.scope, nil]
        else
          id = model[reflection.foreign_key]
          return unless id
          [reflection.klass, :id, id, reflection.scope, nil]
        end
      else
        if reflection.type
          [
            reflection.klass,
            reflection.foreign_key,
            model.id,
            reflection.scope,
            {reflection.type => model.class.name}
          ]
        else
          [
            reflection.klass,
            reflection.foreign_key,
            model.id,
            reflection.scope,
            nil
          ]
        end
      end
    end

    def preload paths
      return @cache[paths] if @cache[paths]
      cache = {}
      *parent_paths, name = paths
      parents = preload(parent_paths).values.flatten
      klass_conditions = {}
      conditions = parents.map do |model|
        reflection = model.reflections[name]
        klass, key, value, scope, cond = conditions_for model, name
        next unless klass
        if reflection.through_reflection
          through_name = reflection.through_reflection.name
          source_name = reflection.source_reflection.name
          siblings = preload [*parent_paths, through_name, source_name]
          throughs = load parent_paths, model, through_name
          (cache[[klass, key, value, scope,cond]] ||= []).concat throughs.map{|through|
            load [*parent_paths, through_name], through, source_name
          }.flatten          
        else
          klass_conditions[[klass, key, scope, cond]]||=[]
          klass_conditions[[klass, key, scope, cond]] << value
        end
      end

      klass_conditions.each do |kkc, values|
        klass, key, scope, cond = kkc
        relation = klass.where(cond).where(key => values)
        relation = relation.instance_eval &scope if scope
        relation.each{|model|
          (cache[[klass, key, model[key], scope, cond]] ||= []) << model
        }
      end
      @cache[paths] = cache
      cache
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
        Relation.new @root, ->{@root.load @path, @model, name}, [*@path, name], @model
      else
        child = @root.load @path, @model, name
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
        @collection_array ||= @collection.call
        @collection_array.map{|model|
          Model.new (@root||self), model, (@path||[])
        }.send(name, *args, &block)
      end
    end

    [:count, :size].each do |name|
      define_method name do |*args, &block|
        unless block
          *parent_paths, child_path = @path
          begin
            return @root.count parent_paths, @parent, child_path
          rescue NotImplemented => e
          end
        end
        @collection_array ||= @collection.call
        @collection_array.send(name, *args, &block)
      end
    end

    def method_missing name, *args, &block
      @collection_array ||= @collection.call
      @collection_array.send name, *args, &block
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
    N1Safe::Relation.new root, ->{to_a}, [], nil
  end
end

##controller
##includesとかはせずにとりあえずn1_safeを付けておく
@posts = Post.all.n1_safe
#Post load (X.Xms) SELECT "posts".* FROM "posts"

##view
##なにも考えずにeachとかまわしまくる
<% @posts.each do |post| %>
  <h1><%= post.title %> | <%= post.user.name %></h1>
  <p><%= post.body %></p>
  <% post.comments.each do |comment| %>
    <%= comment.user.name %>
    <%= comment.text %>
    <%= comment.stars.map(&:user).map(&:name) %>
  <% end %>
<% end %>
#必要になった時にloadされるイメージ(今でも部分的には動くはず)
#Comment load (X.Xms) SELECT "comments".* FROM "comments" WHERE "comments"."post_id" IN (1,2)
#User load (X.Xms) SELECT "users".* FROM "users" WHERE "users"."user_id" IN (3,4,5)
#Star load (X.Xms) SELECT "stars".* FROM "stars" WHERE "stars"."comment_id" IN (1,3,4,5)
#User load (X.Xms) SELECT "users".* FROM "users" WHERE "users"."user_id" IN (1,2,3,4,7,8)

module N1Safe
  class LazyLoader
    def initialize bases
      @bases = bases
      @cache = {}
      @cache[[]] = bases
    end
    def load paths, model, name
      child_siblings = preload [*paths, name]
      klass, key, value, cond = conditions_for model, name
      multiple = model.reflections[name].collection?
      return multiple ? [] : nil unless klass
      childs = child_siblings.select do |child|
        klass === child && child[key] == value && (!cond || cond.all?{|k,v|child[k]==v})
      end
      multiple ? childs : childs.first
    end

    def conditions_for model, name
      reflection = model.reflections[name]
      return unless reflection
      if reflection.belongs_to?
        if reflection.polymorphic?
          type = model[reflection.foreign_type]
          id = model[reflection.foreign_key]
          return unless type && id
          [type.constantize, :id, id]
        else
          id = model[reflection.foreign_key]
          return unless id
          [reflection.klass, :id, id]
        end
      else
        if reflection.type
          [
            reflection.klass,
            reflection.foreign_key,
            model.id,
            {reflection.type => model.name}
          ]
        else
          [
            reflection.klass,
            reflection.foreign_key,
            model.id
          ]
        end
      end
    end

    def preload paths
      return @cache[paths] if @cache[paths]
      cache = []
      *parent_paths, name = paths
      parents = preload parent_paths
      klass_conditions = {}
      conditions = parents.map do |model|
        klass, key, val, cond = conditions_for model, name
        next unless klass
        klass_conditions[[klass, key, cond]]||=[]
        klass_conditions[[klass, key, cond]] << val
      end

      klass_conditions.each do |kkc, vals|
        klass, key, cond = kkc
        cache.concat klass.where(cond).where(key => vals).to_a
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
        collection = @root.load @path, @model, name
        Relation.new @root, collection, [*@path, name]
      else
        child = @root.load @path, @model, name
        Model.new @root, child, [*@path, name] if child
      end
    end
  end

  class Relation < BasicObject
    def initialize root, collection, path
      @root = root
      @collection = collection
      @path = path
    end

    ::Enumerator.instance_methods.each do |name|
      define_method name do |*args, &block|
        @collection.map{|model|
          Model.new (@root||self), model, (@path||[])
        }.send(name, *args, &block)
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
    N1Safe::Relation.new root, to_a, []
  end
end


authorization do
  role :guest do
    has_permission_on [:pages], :to => [:home, :contact, :about, :kale, :FAQ]
    has_permission_on [:feedbacks], :to => [:create]
    has_permission_on [:visitors], :to => [:create]
    has_permission_on [:rcpqueries], :to => [:create, :read, :update]
  end
  
  role :user do
    includes :guest
    has_permission_on [:recipes], :to => [:read, :create, :update, :delete]
    #has_permission_on [:accounts, :categories, :matches, :transactions], :to => :create
    #has_permission_on [:accounts, :categories, :matches, :transactions], :to => :manage do
    #  if_attribute :user => is { user }
    #end
  end
  
  role :moderator do
      includes :user
  end
  
  role :editor do
      includes :moderator
  end
  
  role :admin do
    includes :editor
    # :sessions, :users
    has_permission_on [:recipes], :to => [:destroy]
    has_permission_on [:users], :to => [:manage]
    has_permission_on [:expressions, :feedbacks, :links, :pages, :ratings, :rcpqueries, :recipes, :referents, :scales, :sites, :tags, :visitors], :to => :manage
  end
end

privileges do
  privilege :create do
    includes :new
  end
  privilege :read do
    includes :index, :show, :relist, :piclist, :touch
  end
  privilege :update do
    includes :edit
  end
  privilege :destroy do
    includes :destroy
  end
  privilege :delete do
    includes :remove
  end
  
  privilege :manage do
    includes :create, :read, :update, :delete
  end
  
#  privilege :read, :pages, :includes => [:home, :contact, :about, :kale, :FAQ]
end
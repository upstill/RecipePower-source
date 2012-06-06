authorization do
  role :guest do
    has_permission_on [:pages], :to => [:home, :contact, :about, :kale, :FAQ]
    has_permission_on [:feedbacks], :to => [:create]
    has_permission_on [:visitors], :to => [:create]
    has_permission_on [:rcpqueries], :to => [:create, :read]
  end
  
  role :admin do
    includes :guest
    # :sessions, :users
    has_permission_on [:expressions, :feedbacks, :links, :pages, :ratings, :rcpqueries, :recipes, :referents, :scales, :sites, :tags, :visitors], :to => :manage
  end
  
  role :user do
    includes :guest
    #has_permission_on [:accounts, :categories, :matches, :transactions], :to => :create
    #has_permission_on [:accounts, :categories, :matches, :transactions], :to => :manage do
    #  if_attribute :user => is { user }
    #end
  end
end

privileges do
  privilege :create do
    includes :new
  end
  privilege :read do
    includes :index, :show
  end
  privilege :update do
    includes :edit
  end
  privilege :delete do
    includes :destroy
  end
  
  privilege :manage do
    includes :create, :read, :update, :delete
  end
  
#  privilege :read, :pages, :includes => [:home, :contact, :about, :kale, :FAQ]
end
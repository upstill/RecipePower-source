authorization do
  role :guest do
    has_permission_on [:pages], :to => [:home, :contact, :about, :welcome, :FAQ]
    has_permission_on [:visitors], :to => [:create]
    has_permission_on [:rcpqueries], :to => [:create, :read, :update, :tablist, :relist]
    has_permission_on [:recipes], :to => [:read, :create, :collect, :capture, :untag]
    has_permission_on [:tags], :to => [:show, :match, :query ]
  end
  
  role :user do
    includes :guest
    has_permission_on [:recipes], :to => [ :subscribe, :update, :delete, :piclist, :touch ]
    has_permission_on [:tags], :to => [:read]
    has_permission_on [:feeds], :to => [:index, :show, :subscribe]
    
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
      has_permission_on [:tags], :to => [:manage]
      has_permission_on [:referents], :to => [:manage]
  end
  
  role :admin do
    includes :editor
    # :sessions, :users
    has_permission_on [:pages], :to => [:admin]
    has_permission_on [:tags], :to => [:destroy]
    has_permission_on [:recipes], :to => [:destroy]
    has_permission_on [:feeds], :to => [:edit, :approve, :destroy]
    has_permission_on [:sites], :to => [:edit, :approve, :destroy]
    has_permission_on [:finders], :to => [:edit, :approve, :destroy]
    has_permission_on [:users], :to => [:manage]
    has_permission_on [:expressions, :links, :pages, :ratings, :rcpqueries, :recipes, :referents, :scales, :sites], :to => :manage
  end
end

privileges do
  privilege :subscribe do
    includes :collect, :remove
  end
  privilege :create do
    includes :new
  end
  privilege :read do
    includes :index, :show
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
    includes :create, :read, :update, :delete, :editor, :typify, :absorb
  end
  
#   privilege :read, :pages, :includes => [:home, :contact, :about, :FAQ, :welcome]
end
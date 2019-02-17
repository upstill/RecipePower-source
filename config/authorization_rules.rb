authorization do
  role :guest do
    has_permission_on [:pages], :to => [:home, :contact, :about, :welcome, :FAQ, :root]
    has_permission_on [:visitors], :to => [:create]
    has_permission_on [:recipes], :to => [:read, :create, :collect, :capture, :uncollect, :touch]
    has_permission_on [:referents], :to => [:read]
    has_permission_on [:lists, :feeds, :feed_entries, :sites, :users, :page_refs, :referents], :to => [:touch]
    has_permission_on [:tags], :to => [ :read, :match, :query ]
    has_permission_on [:users], :to => [ :unsubscribe, :collection ] # ...following pre-authorized links
    has_permission_on [:sessions], :to => [ :create, :new ]
  end

  role :user do
    includes :guest
    has_permission_on [:recipes, :lists, :feeds, :feed_entries, :sites, :users, :page_refs, :referents], :to => [:touch, :update, :lists, :tag, :editpic, :glean]
    has_permission_on [:users], :to => [:edit, :update, :notifications ] # BUT ONLY FOR ONESELF
    has_permission_on [:recipes], :to => [:subscribe, :update, :delete]
    has_permission_on [:tags], :to => [:read]
    has_permission_on [:feeds, :referents], :to => [:index, :show, :subscribe]
    has_permission_on [:lists], :to => [:index, :show, :subscribe, :edit, :update]
    has_permission_on [ :notifications_with_devise ], :to => [ :index ]
    has_permission_on [:sessions], :to => [ :destroy ]
    has_permission_on [:page_refs], :to => [ :new, :create ]

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
    has_permission_on [:tags, :referents, :lists, :feeds], :to => [:manage]
    has_permission_on [:tags], :to => [ :define ]
    has_permission_on [:feeds], :to => [ :rate ]
  end

  role :admin do
    includes :editor
    # :sessions, :users
    has_permission_on :scrapers, :to => [:new, :create, :init]
    has_permission_on [:pages, :lists, :recipes, :feeds, :sites, :users, :finders], :to => [:admin]
    has_permission_on [:tags, :lists, :recipes, :feeds, :sites, :finders, :page_refs], :to => [:destroy]
    has_permission_on [:feeds, :sites, :finders], :to => [:approve]
    has_permission_on [:users, :expressions, :links, :pages, :ratings, :recipes, :referents, :scales, :sites], :to => :manage
    has_permission_on [:editions], :to => [:new, :create, :update, :destroy]
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
    includes :index, :show, :associated
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
    includes :create, :read, :update, :delete, :editor, :typify, :associate
  end

#   privilege :read, :pages, :includes => [:home, :contact, :about, :FAQ, :welcome]
end

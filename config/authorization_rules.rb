authorization do
  role :guest do
    has_permission_on [:public], :to => [:read]
  end
  
  role :administrator do
    has_permission_on :public, :to => [:read, :create]
    has_permission_on [:accounts, :categories, :matches, :transactions, :users, :roles], :to => :manage
  end
  
  role :accountant do
    includes :guest
  end
  
  role :user do
    has_permission_on :public, :to => [:read, :create]
    has_permission_on [:accounts, :categories, :matches, :transactions], :to => :create
    has_permission_on [:accounts, :categories, :matches, :transactions], :to => :manage do
      if_attribute :user => is { user }
    end
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
  
  privilege :create, :public, :includes => :upload
  privilege :create, :categories, :includes => :sort
  privilege :create, :matches, :includes => :guess
end
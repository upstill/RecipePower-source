RP::Application.routes.draw do

  get "notifications/accept"
  
=begin
  resources :notifications do 
    member do
      put 'accept'
    end
  end
=end

  resources :references

  get "references/index"

  get "references/create"

  get "references/new"

  get "references/edit"

  get "references/show"

  get "references/update"

  get "references/destroy"

  resources :feeds do
    member do 
      get 'collect' # Add the feed to the current user
      post 'remove' # Remove the feed from the current user's set
      post 'approve' # (Admin only) approve the feed for presentation
    end
    collection do
      post 'query' # Change the selection query
    end
  end

  resources :thumbnails

  match 'collection', :controller=>'collection', :action=>'index', :via => [:get, :post]
  match 'collection/query', :controller=>'collection', :action=>'query', :via => :post
  match "collection/update", :controller=>'collection', :action=>'update', :via => :post
  get "collection/feed"
  get "collection/show"
  get "collection/new"
  get "collection/edit"
  get "collection/create"
  get "collection/relist"

  get "stream/stream"
  
  get "show/new"

  get "show/edit"

  get "show/create"

  get "show/relist"

  get "show/update"

  get "iframe/create"

  # get "bm/bookmarklet(.:format)" => "bm#bookmarklet", :as => :bookmarklet

  resources :feedback, :only => [:new, :create]

  get '/auth/failure' => 'authentications#failure'
  get '/authentications/new' => 'authentications#new'
  resources :authentications
     
  devise_for :users, :controllers => {
    :sessions => 'sessions', 
    :passwords => 'passwords', 
    :invitations => 'invitations', 
    :registrations => 'registrations'}

  get '/site/scrape' => 'sites#scrape'
  resources :sites
  match 'sites/query', :controller=>'sites', :action=>'query', :via => :post
  resources :expressions
  resources :referents
  match 'references/query', :controller=>'references', :action=>'query', :via => :post
  resources :references

  get '/auth/:provider/callback' => 'authentications#create'

  # Calling 'profile' action in 'users' controller edits the current user
  get 'users/profile' => 'users#profile'
  # Ask a user to identify him/herself by email address
  get 'users/identify' => 'users#identify'
  # get 'users/:id/show' => 'users#show'
  resources :users do
    member do 
      get 'collect'
      post 'remove'
      get 'match_friends'
      get 'notify'
      get 'acquire' # Acquire a recipe (etc.)
    end
    collection do
      post 'query' # Change the selection query
    end
  end

  # Super-user can edit user info, starting with roles
  #match 'signup' => 'users#new', :as => :signup
  #match 'logout' => 'sessions#destroy', :as => :logout
  #match 'login' => 'sessions#new', :as => :login
  #resources :sessions
  #resources :users

  resources :tags do 
    member do
      get 'absorb'
    end
    collection do
      post 'query'
      get 'editor'
      get 'list'
      get 'typify'
      get 'match'
    end
  end

  resources :ratings

  resources :scales
  
  # match 'recipes/capture' => 'recipes#capture'
  # match 'recipes/:id/collect' => 'recipes#collect'
  # match 'recipes/:id/touch' => 'recipes#touch'
  # match 'recipes/:id/piclist' => 'recipes#piclist'
  # match 'recipes/:id/remove' => 'recipes#remove'
  # match 'recipes/:id/destroy' => 'recipes#destroy'
  # match 'recipes/:id/show' => 'recipes#show'
  # match 'recipes/parse' => 'recipes#parse', :via => :post
  # match 'recipes/:id' => 'recipes#update', :via => :post
  resources :recipes do
    member do 
      get 'collect'
      get 'touch'
      get 'piclist'
      post 'remove'
    end
    collection do
      get 'capture'
      post 'parse'
    end
  end

  get '/revise', :to => 'recipes#revise'

  # get "pages/home"
  # get "pages/contact"
  # get "pages/about"
  get '/home', :to => 'pages#home'
  get '/popup', :to => 'pages#popup'
  get '/share', :to => 'pages#share'
  get '/contact', :to => 'pages#contact'
  get '/about', :to => 'pages#about'
  get '/welcome', :to => 'pages#welcome'
  get '/faq', :to=>"pages#faq"
  get '/admin', :to=>"pages#admin"
  root :to => 'pages#root'

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   get 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   get 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # get ':controller(/:action(/:id(.:format)))'
end

# Most of this is fairly generic except for added controller methods. The main oddity
# is querying collections via the index action. POSTing to #index modifies query parameters,
# whereas GETting from #index starts afresh. This overloading was necessitated by problems using
# a second, POST, method (#query), which wasn't being POSTed to upon page reload.

unless @RPRoutesLoaded
  @RPRoutesLoaded = true

RP::Application.routes.draw do

  if Rails.env.development? || Rails.env.test?
    # IntegersController is for testing streams
    get "integers/index"
  end
  resources :votes, :only => :create
  post '/votes/recipes/:recipe_id' => 'votes#create', :as => "vote_recipe"
  get 'pic_picker/new' => 'pic_picker#new'

  get "redirect/go"
  get '/auth/failure' => 'authentications#failure'
  # get '/authentications/new' => 'authentications#new'
  resources :authentications

  devise_for :users, :skip => [ :registrations ], :controllers => {
      :sessions => 'sessions',
      :passwords => 'passwords',
      :invitations => 'invitations',
      # :registrations => 'registrations' # Had to elide this and use devise_scope to define /users/register instead of /users to create
  }

  match 'users', :controller=>'users', :action=>'index', :via => [:get, :post]

  devise_scope :user do
    post "/users/register" => "registrations#create", :as => "user_registration"
    get "/users/sign_up" => "registrations#new", :as => "new_user_registration"
    get "/users/edit" => "registrations#edit", :as => "edit_user_registration"
    get "/users/cancel" => "registrations#cancel", :as => "cancel_user_registration"
    put "/users" => "registrations#update"
    delete "/users" => "registrations#destroy"
    get "/users/sign_out" => "sessions#destroy"
    patch "/users" => "registrations#update"

    get "/users/invitation/divert" => "invitations#divert", :as => "divert_user_invitation"
  end

  get '/auth/:provider/callback' => 'authentications#create'
  post '/auth/:provider/callback' => 'authentications#create'

  # Calling 'profile' action in 'users' controller edits the current user
  get 'users/profile' => 'users#profile'
  # Ask a user to identify him/herself by email address
  get 'users/identify' => 'users#identify'
  # get 'users/:id/show' => 'users#show'
  resources :users, :except => [ :index, :create ] do
    member do
      get 'collect'
      post 'remove'
      get 'match_friends'
      get 'notify'
      get 'acquire' # Acquire a recipe (etc.)
    end
  end

  post '/list' => 'lists#create', :as => 'create_list'
  resources :lists, except: [ :index, :create ] do
    member do
      get 'scrape'
    end
  end
  match 'lists', :controller=>'lists', :action=>'index', :via => [:get, :post]

  post '/site' => 'sites#create', :as => 'create_site'
  resources :sites, except: [ :index, :create ] do
    member do
      get 'scrape'
    end
  end
  match 'sites', :controller=>'sites', :action=>'index', :via => [:get, :post]

  post '/reference' => 'references#create', :as => 'create_reference'
  resources :references, :except => [ :index, :create ]
  match 'references', :controller=>'references', :action=>'index', :via => [:get, :post]

  post '/feed' => 'feeds#create', :as => 'create_feed'
  resources :feeds, :except => [ :index, :create ] do
    member do
      get 'collect' # Add the feed to the current user
      post 'remove' # Remove the feed from the current user's set
      post 'approve' # (Admin only) approve the feed for presentation
    end
  end
  match 'feeds', :controller=>'feeds', :action=>'index', :via => [:get, :post]

  post '/tag' => 'tags#create', :as => 'create_tag'
  resources :tags, except: [ :index, :create ] do
    member do
      post 'absorb'
    end
    collection do
      get 'editor'
      get 'list'
      get 'typify'
      get 'match'
    end
  end
  match 'tags', :controller=>'tags', :action=>'index', :via => [:get, :post]

  match 'collection', :controller=>'collection', :action=>'index', :via => [:get, :post]
  post 'collection/update'
  get "collection/refresh"
  get "collection/feed"
  get "collection/show", as: 'collection_show'
  get "collection/new"
  get "collection/edit"
  post "collection/create"
  get "collection/relist"

  get "stream/stream"
  get "stream/buffer_test"
  get "iframe/create"
  get "admin/data"
  get "admin/control"
  get "notifications/accept"

  resources :thumbnails
  resources :feedback, :only => [:new, :create]
  resources :expressions
  resources :referents
  resources :ratings
  resources :scales

  resources :recipes do
    resources :tags do
      member { post 'remove', :to => 'recipes#untag' }
    end
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
  get '/popup/:name', :to => 'pages#popup'
  get '/popup', :to => 'pages#popup'
  get '/share', :to => 'pages#share'
  get '/contact', :to => 'pages#contact'
  get '/about', :to => 'pages#about'
  get '/welcome', :to => 'pages#welcome'
  get '/faq', :to=>"pages#faq"
  get '/admin', :to=>"pages#admin"
  get '/mobi', :to=>"pages#mobi"
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
end

# Most of this is fairly generic except for added controller methods. The main oddity
# is querying collections via the index action. POSTing to #index modifies query parameters,
# whereas GETting from #index starts afresh. This overloading was necessitated by problems using
# a second, POST, method (#query), which wasn't being POSTed to upon page reload.
puts (["!!!! Loading #{__FILE__} from #{caller.first} !!!!"] + caller).join("\n  >> ")
puts
RP::Application.routes.draw do
  root 'pages#root'

  resources :page_refs
  get 'scraper/new'

  post 'scraper/create'
  post 'scraper/init'

  get 'finders/create'
  post 'finders/create'

  resources :gleanings, :only => [:new, :create, :show]

  concern :picable do
    member do
      get 'editpic' # Open dialog to acquire an image from various sources
    end
  end

  concern :collectible do
    member do
      get 'touch'
      get 'associated'
      patch 'collect'
    end
  end

  concern :taggable do
    member do
      # Routes for taggables
      get 'tag' # Present the dialog for tagging and commenting
      patch 'tag'
      get 'lists'  # Present the dialog for managing the lists it's on
      patch 'lists'
    end
  end

  get 'search/index'

  resources :tagsets

  resources :answers

  if Rails.env.staging?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  get "admin/toggle"
  resources :feed_entries, :except => [:index, :create, :new], :concerns => [:taggable, :collectible]

  resources :suggestions do
    member do
      get 'results'
    end
  end

  if Rails.env.development? || Rails.env.test?
    # IntegersController is for testing streams
    get "integers" => 'integers#index'
  end

    post '/votes/recipe/:id' => 'votes#create'
    post '/votes/feed/:id' => 'votes#create'
    post '/votes/feed_entry/:id' => 'votes#create'
    post '/votes/list/:id' => 'votes#create'
    post '/votes/product/:id' => 'votes#create'
    post '/votes/site/:id' => 'votes#create'
    post '/votes/user/:id' => 'votes#create'

  # get "redirect/go", :as => "goto"
  # put "redirect/go"
  get '/auth/failure' => 'authentications#failure'
  # get '/authentications/new' => 'authentications#new'
  resources :authentications

=begin
  devise_for :users, :skip => [:registrations], :controllers => {
      :sessions => 'sessions',
      :passwords => 'passwords',
      :invitations => 'invitations',
      # :registrations => 'registrations' # Had to elide this and use devise_scope to define /users/register instead of /users to create
  }
=end

  match 'users', :controller => 'users', :action => 'index', :via => [:get, :post]

=begin
  devise_scope :user do
    put "/users/password/new" => 'passwords#new' # To handle redirects from edit
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
=end

  get '/auth/:provider/callback' => 'authentications#create'
  post '/auth/:provider/callback' => 'authentications#create'

  # Calling 'profile' action in 'users' controller edits the current user
  get 'users/profile' => 'users#profile'
  # Ask a user to identify him/herself by email address
  get 'users/identify' => 'users#identify'
  get 'users/:id/recent' => 'users#recent', :as => "user_recent"
  get 'users/:id/recent' => 'users#recent', :as => "user_root"
  get 'users/:id/collection' => 'users#collection', :as => "collection_user"
  get 'users/:id/biglist' => 'users#biglist', :as => "user_biglist"
  # get 'users/:id/show' => 'users#show'
  resources :users, :except => [:index, :create], :concerns => [ :picable, :taggable, :collectible] do
    member do
      get 'match_friends'
      get 'notify'
      get 'acquire' # Acquire a recipe (etc.)
      post 'follow'
      get 'getpic'
      patch 'sendmail'
      get 'sendmail', :as => "mailto"
    end
  end

  post '/list' => 'lists#create', :as => 'create_list'
  resources :lists, except: [:index, :create], :concerns => [:picable, :taggable, :collectible] do
    member do
      post 'pin' # Add an entity to a list
      get 'contents'
    end
  end
  match 'lists', :controller => 'lists', :action => 'index', :via => [:get, :post]

  post '/site' => 'sites#create', :as => 'create_site'
  resources :sites, except: [:index, :create, :destroy], :concerns => [:picable, :collectible, :taggable] do
    member do
      post 'absorb'
      get 'feeds'
      post 'approve' # (Admin only) approve the site for presentation
    end
  end
  match 'sites', :controller => 'sites', :action => 'index', :via => [:get, :post]

  post '/reference' => 'references#create', :as => 'create_reference'
  resources :references, :except => [:index, :create]
  match 'references', :controller => 'references', :action => 'index', :via => [:get, :post]

  post '/feed' => 'feeds#create', :as => 'create_feed'
  # get 'feeds/:id/owned' => 'feeds#owned', :as => "owned_feed"
  resources :feeds, :except => [:index, :create], :concerns => [:picable, :collectible, :taggable] do
    member do
      get 'refresh' # Refresh the feed's entries
      get 'contents'
      post 'approve' # (Admin only) approve the feed for presentation
    end
  end
  match 'feeds', :controller => 'feeds', :action => 'index', :via => [:get, :post]

  resources :tag_selections

  post '/tag' => 'tags#create', :as => 'create_tag'
  resources :tags, except: [:index, :create] do
    member do
      post 'absorb'
      get 'owned'
      get 'associated'
    end
    collection do
      get 'editor'
      get 'list'
      get 'typify'
      get 'match'
    end
  end
  match 'tags', :controller => 'tags', :action => 'index', :via => [:get, :post]

  match 'search', :controller => 'search', :action => 'index', :via => :get
=begin
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
=end

  get 'iframe/create'
  get 'admin/data'
  get 'admin/control'
  get 'notifications/accept'
  patch 'notifications/act'

  resources :feedback, :only => [:new, :create]
  resources :expressions
  resources :referents
  resources :referents do
    member do
      get 'associated'
    end
  end
  resources :ratings
  resources :scales

  resources :recipes, :concerns => [:picable, :collectible, :taggable] do
    member do
      get 'piclist'
    end
    collection do
      get 'capture'
      post 'parse'
    end
  end
  get '/revise', :to => 'recipes#revise'
  get '/scrape', :to => 'page_refs#scrape'

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
  get '/faq', :to => "pages#faq"
  get '/admin', :to => "pages#admin"
  get '/sprites', :to => "pages#sprites"
  get '/cookmark', :to => "pages#cookmark"
  # Challenge response for Lets Encrypt
  get '/.well-known/acme-challenge/:id' => 'pages#letsencrypt'

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
puts "!!!! Leaving #{__FILE__} from #{caller.first} !!!!"

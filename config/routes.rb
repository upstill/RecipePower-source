# Most of this is fairly generic except for added controller methods. The main oddity
# is querying collections via the index action. POSTing to #index modifies query parameters,
# whereas GETting from #index starts afresh. This overloading was necessitated by problems using
# a second, POST, method (#query), which wasn't being POSTed to upon page reload.

RP::Application.routes.draw do
  resources :recipe_pages
  resources :offerings
  resources :editions

  get 'rp_events/show'

  get 'rp_events/show_page'

  get 'rp_events/index'

  get 'rp_events/new'

  get 'rp_events/create'

  get 'rp_events/update'

  get 'rp_events/destroy'

  get 'scraper/new'
  post 'scraper/create'
  post 'scraper/init'

  get 'finders/create'
  post 'finders/create'

  concern :picable do
    member do
      get 'editpic' # Open dialog to acquire an image from various sources
      get 'glean/:what', :action => 'glean', :what => /titles|descriptions|images|feeds|table|card|masonry|slider/, :as => 'glean'
    end
  end

  concern :collectible do
    member do
      get 'touch'
      get 'associated'
      patch 'collect'
      get 'card' # Provide a card for display via JSON
      # get 'cardlet' # Provide a cardlet for display via JSON
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

  resources :page_refs, :concerns => [:taggable, :collectible, :picable] do
    collection do
      get 'tag'
      put 'create'
      post 'create'
    end
  end

  # Referments are a join table used to link Referents to a wide variety of "See Also" entities (PageRef, Recipe, ImageReference, Referent...)
  # We only create or edit referments in the context of the associated Referent
  resources :referments, :only => [:show, :create, :update, :destroy] do
    collection do
      put 'create'
    end
  end

  resources :tagsets

  resources :answers

  if Rails.env.staging?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  get "admin/toggle"
  resources :feed_entries, :except => [:index, :create, :new], :concerns => [:taggable, :collectible, :picable]

  resources :suggestions do
    member do
      get 'results'
    end
  end

  if Rails.env.development? || Rails.env.test?
    # IntegersController is for testing streams
    get "integers" => 'integers#index'
  end

  post '/votes/:entity/:id' => 'votes#create', :entity => /recipe|feed|feed_entry|list|product|site|user|referent/

  get "redirect/go", :as => "goto"
  put "redirect/go"
  get '/auth/failure' => 'authentications#failure'
  get 'defer_invitation' => 'application#defer_invitation'
  get 'menu' => 'application#menu'
  # get '/authentications/new' => 'authentications#new'
  resources :authentications

  get '/auth/:provider/callback' => 'authentications#create'
  post '/auth/:provider/callback' => 'authentications#create'

  devise_for :users, :skip => [:registrations], :controllers => {
                       :sessions => 'sessions',
                       :passwords => 'passwords',
                       :invitations => 'invitations',
                       # :registrations => 'registrations' # Had to elide this and use devise_scope to define /users/register instead of /users to create
                   }

  match 'users', :controller => 'users', :action => 'index', :via => [:get, :post]

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

  authenticate do
    # Integrated with devise
    notify_to :users, with_devise: :users, controller: 'users/notifications_with_devise'
  end

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
      get 'unsubscribe'
      get 'sendmail', :as => "mailto"
    end
  end

  post '/list' => 'lists#create', :as => 'create_list'
  resources :lists, except: [:index, :create], :concerns => [:picable, :taggable, :collectible] do
    member do
      post 'pin' # Add an entity to a list
      # We allow lists to do gleaning to get an image
      get 'contents'
    end
  end
  match 'lists', :controller => 'lists', :action => 'index', :via => [:get, :post]

  post '/site' => 'sites#create', :as => 'create_site'
  resources :sites, except: [:index, :create], :concerns => [:picable, :collectible, :taggable] do
    member do
      post 'absorb'
      get 'feeds'
      post 'approve' # (Admin only) approve the site for presentation
    end
  end
  match 'sites', :controller => 'sites', :action => 'index', :via => [:get, :post]

  # post '/image_reference' => 'image_references#create', :as => 'create_image_reference'
  resources :image_references #, :except => [:index, :create]
  # match 'image_references', :controller => 'image_references', :action => 'index', :via => [:get, :post]
  resources :gleanings
  resources :mercury_results

  post '/feed' => 'feeds#create', :as => 'create_feed'
  # get 'feeds/:id/owned' => 'feeds#owned', :as => "owned_feed"
  resources :feeds, :except => [:index, :create], :concerns => [:picable, :collectible, :taggable] do
    member do
      get 'refresh' # Refresh the feed's entries
      get 'contents'
      post 'approve' # (Admin only) approve the feed for presentation
      post 'rate'
    end
  end
  match 'feeds', :controller => 'feeds', :action => 'index', :via => [:get, :post]

  resources :tag_selections

  post '/tag' => 'tags#create', :as => 'create_tag'
  resources :tags, except: [:index, :create] do
    member do
      post 'associate'
      get 'owned'
      get 'associated'
      post 'define'
    end
    collection do
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

  resources :feedback, :only => [:new, :create]
  resources :expressions
  resources :referents, :concerns => [:picable, :collectible, :taggable] do
    member do
      get 'associated'
    end
  end
  resources :ratings
  resources :scales

  resources :recipes, :concerns => [:picable, :collectible, :taggable] do
    member do
      get 'piclist'
      get :recipe_page
      post :recipe_page
      resource :recipe_contents do
        patch 'annotate'
      end
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
  get '/privacy', :to => 'pages#privacy'
  get '/popup/:name', :to => 'pages#popup'
  get '/popup', :to => 'pages#popup'
  get '/share', :to => 'pages#share'
  get '/tell_me_more', :to => 'pages#tell_me_more'
  get '/contact', :to => 'pages#contact'
  get '/about', :to => 'pages#about'
  get '/mission', :to => 'pages#mission'
  get '/welcome', :to => 'pages#welcome'
  get '/faq', :to => 'pages#faq'
  get '/admin', :to => 'pages#admin'
  get '/sprites', :to => 'pages#sprites'
  get '/cookmark', :to => 'pages#cookmark'
  get '/collect', :to => 'pages#collect'
  # Challenge response for Lets Encrypt
  get '/.well-known/acme-challenge/:id' => 'pages#letsencrypt'
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

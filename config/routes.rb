RP::Application.routes.draw do

  resources :feedbacks

  resources :sites

  resources :expressions

  resources :referents

  resources :links

  match 'rcpqueries/relist', :controller=>'rcpqueries', :action=>'relist', :via => :get
  match 'rcpqueries/:id/relist', :controller=>'rcpqueries', :action=>'relist', :via => :get

  resources :rcpqueries

  match 'rcpqueries/:id' => 'rcpqueries#update', :via => :post

  match 'user/edit' => 'users#edit', :as => :edit_current_user

  match 'signup' => 'users#new', :as => :signup

  match 'logout' => 'sessions#destroy', :as => :logout

  match 'login' => 'sessions#new', :as => :login

  resources :sessions

  resources :users

  match 'tags/editor', :controller=>'tags', :action=>'editor', :via => :get
  match 'tags/list', :controller=>'tags', :action=>'list', :via => :get
  match 'tags/typify', :controller=>'tags', :action=>'typify'
  match 'tags/match', :controller=>'tags', :action=>'match'
  match 'tags/:id/absorb', :controller=>'tags', :action=>'absorb'
  resources :tags

  resources :ratings

  resources :scales
  
  match 'recipes/:id/piclist' => 'recipes#piclist'
  match 'recipes/parse' => 'recipes#parse', :via => :post
  resources :recipes
  match 'recipes/:id' => 'recipes#update', :via => :post

  match '/revise', :to => 'recipes#revise'

  # get "visitors/new"
  resources :visitors

  # get "pages/home"
  # get "pages/contact"
  # get "pages/about"
  match '/contact', :to => 'pages#contact'
  match '/about', :to => 'pages#about'
  match '/welcome', :to => 'pages#welcome'
  match '/kale', :to => 'pages#kale'
  match '/signup', :to => 'visitors#new'
  match '/FAQ', :to=>"pages#FAQ"
  root :to => 'pages#home'

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
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
  # match ':controller(/:action(/:id(.:format)))'
end

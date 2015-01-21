Rails.application.routes.draw do

  namespace :api do
    namespace :v1 do
      resource :upload, only: [:create]
      resources :photos, only: [:index, :show]
      resources :pics, only: [:index, :show] do
        post 'flag', on: :collection
        get 'details', on: :collection
      end

#      resources :display_names
#      resources :faces
#      resources :hosting_service_accounts
#      resources :people
#      resources :service_collections
    end
  end

  resources :flickr, only: [] do
    resources :photos, only: [:index]
  end

  resources :a, only: [:show] do
    resources :pics, only: [:index] #   # shows all the photos in the account
  end
# mugs/[id]  # shows all the people in the account

end

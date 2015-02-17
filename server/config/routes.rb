Rails.application.routes.draw do

  namespace :api do
    namespace :v1 do
      resource :upload, only: [:create]
      resources :photos, only: [:index, :show]
      resources :pics, only: [:index, :show, :update] do
        get 'details', on: :collection
      end
      resources :faces, only: [:create, :update, :destroy] do
      end
      resources :names, only: [:index]
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

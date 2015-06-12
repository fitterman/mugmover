Rails.application.routes.draw do

  devise_for :users
  root controller: :go, action: :show, id: 1
  namespace :api do
    namespace :v1 do
      resource :upload, only: [:create]
      # resource :flickr, only: [:index, :show]
      resources :photos, only: [:index, :show, :update] do
        get 'details', on: :collection
      end
      resources :faces, only: [:create, :update, :destroy] do
        post :restore, on: :member
      end
      resources :names, only: [:index, :show]
    end
  end

  resources :flickr, only: [] do
    resources :photos, only: [:index]
  end

  resources :photos, only: [:show]

  resources :go, only: [:show]

# mugs/[id]  # shows all the people in the account

end

# Put your extension routes here.

map.resources :orders, :member => {:secure_form => :get, :callback_3dsecure => :any, :complete_3dsecure => :any}


# Put your extension routes here.

map.resources :orders, :member => {:enter_3dsecure => :get, :callback_3dsecure => :post, :complete_3dsecure => :post}


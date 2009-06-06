# Put your extension routes here.

map.resources :orders, :member => {:callback_3dsecure => :post, :complete_3dsecure => :post}


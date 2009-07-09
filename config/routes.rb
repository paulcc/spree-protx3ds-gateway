# Put your extension routes here.

map.resources :orders, :has_one => :checkout do |order|
  order.resource :checkout, :member => {:enter_3dsecure => :get, :callback_3dsecure => :post, :complete_3dsecure => :post}
end


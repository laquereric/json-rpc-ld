Rails.application.routes.draw do
  mount JsonRpcLd::Engine => "/json_rpc_ld"
end

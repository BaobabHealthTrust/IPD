ActionController::Routing::Routes.draw do |map|
	map.devise_for :users
  map.root :controller => "people"
  
  # ------------------------------- INSTALLATION GENERATED ----------------------------------------------------
  map.clinic  '/clinic', :controller => 'dde', :action => 'index'
  map.process_result '/process_result', :controller => 'dde', :action => 'process_result'
  map.process_data '/process_data/:id', :controller => 'dde', :action => 'process_data'
  map.search '/search', :controller => 'dde', :action => 'search_name'
  map.new_patient '/new_patient', :controller => 'dde', :action => 'new_patient'
  map.ajax_process_data '/ajax_process_data', :controller => 'dde', :action => {'ajax_process_data' => [:post]}
  map.process_confirmation '/process_confirmation', :controller => 'dde', :action => {'process_confirmation' => [:post]}
  map.patient_not_found '/patient_not_found/:id', :controller => 'dde', :action => 'patient_not_found'
  map.ajax_search '/ajax_search', :controller => 'dde', :action => 'ajax_search'
  # ------------------------------- END OF INSTALLATION GENERATED ----------------------------------------------
  
 #   map.clinic  '/clinic',  :controller => 'clinic', :action => 'index'
  map.create_remote  '/patient/create_remote',  :controller => 'people', :action => 'create_remote'
  map.admin  '/admin',  :controller => 'admin', :action => 'index'
  map.login  '/login',  :controller => 'sessions', :action => 'new'
  map.logout '/logout', :controller => 'sessions', :action => 'destroy'
  map.location '/location', :controller => 'sessions', :action => 'location'
  map.encounter '/encounters/new/:encounter_type', :controller => 'encounters', :action => 'new'  
  map.resource :session
  map.resources :dispensations, :collection => {:quantities => :get}
  map.resources :barcodes, :collection => {:label => :get}
  map.resources :relationships, :collection => {:search => :get}
  map.resources :programs, :collection => {:locations => :get, :workflows => :get, :states => :get}
  map.resources :encounter_types
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/'

end

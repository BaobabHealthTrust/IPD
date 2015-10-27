ActionController::Routing::Routes.draw do |map|
	map.devise_for :users
  
  # ------------------------------- INSTALLATION GENERATED ----------------------------------------------------
  map.root :controller => "dde"
  map.clinic  '/clinic', :controller => 'dde', :action => 'index'
  map.duplicates  '/duplicates', :controller => 'dde', :action => 'duplicates'
  map.dde_search_by_name  '/dde_search_by_name', :controller => 'dde', :action => 'search_by_name'
  map.dde_search_by_id  '/dde_search_by_id', :controller => 'dde', :action => 'search_by_id'
  map.push_merge  '/push_merge', :controller => 'dde', :action => 'push_merge'
  map.process_result '/process_result', :controller => 'dde', :action => 'process_result'
  map.process_data '/process_data/:id', :controller => 'dde', :action => 'process_data'
  map.search '/search', :controller => 'dde', :action => 'search_name'
  map.new_patient '/new_patient', :controller => 'dde', :action => 'new_patient'
  map.ajax_process_data '/ajax_process_data', :controller => 'dde', :action => {'ajax_process_data' => [:post]}
  map.process_confirmation '/process_confirmation', :controller => 'dde', :action => {'process_confirmation' => [:post]}
  map.patient_not_found '/patient_not_found/:id', :controller => 'dde', :action => 'patient_not_found'
  map.ajax_search '/ajax_search', :controller => 'dde', :action => 'ajax_search'
  map.edit_demographics '/patients/edit_demographics', :controller => 'dde', :action => 'edit_patient'
  map.demographics '/people/demographics/:id', :controller => 'dde', :action => 'edit_patient'
  map.demographics '/patients/demographics/:id', :controller => 'dde', :action => 'edit_patient'
  # ------------------------------- END OF INSTALLATION GENERATED ----------------------------------------------
  
 #   map.root :controller => "people"
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

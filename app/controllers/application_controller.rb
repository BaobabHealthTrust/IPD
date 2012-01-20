class ApplicationController < ActionController::Base
	include AuthenticatedSystem
		Mastercard
		PatientIdentifierType
		PatientIdentifier
		PersonAttribute
		PersonAttributeType
		WeightHeight
		CohortTool
		Encounter
		EncounterType
		Location
		DrugOrder
		User
		Task
		GlobalProperty
		Person
		Regimen
		Relationship
		ConceptName
		Concept
		Settings
	require "fastercsv"

	helper :all
	helper_method :next_task
	filter_parameter_logging :password
	before_filter :login_required, :except => ['login', 'logout','demographics','create_remote', 'mastercard_printable']
	before_filter :location_required, :except => ['login', 'logout', 'location','demographics','create_remote', 'mastercard_printable']
  
	def rescue_action_in_public(exception)
		@message = exception.message
		@backtrace = exception.backtrace.join("\n") unless exception.nil?
		logger.info @message
		logger.info @backtrace
		render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
	end if RAILS_ENV == 'development' || RAILS_ENV == 'test'

	def rescue_action(exception)
		@message = exception.message
		@backtrace = exception.backtrace.join("\n") unless exception.nil?
		logger.info @message
		logger.info @backtrace
		render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
	end if RAILS_ENV == 'production'

	def print_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
		@print_url = print_url
		@redirect_url = redirect_url
		@message = message
		@show_next_button = show_next_button
		@patient_id = patient_id
		render :template => 'print/print', :layout => nil
	end

	def print_location_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
		@print_url = print_url
		@redirect_url = redirect_url
		@message = message
		@show_next_button = show_next_button
		render :template => 'print/print_location', :layout => nil
	end

	def show_lab_results
		CoreService.get_global_property_value('show.lab.results').to_s == "true" rescue false
	end

	def use_filing_number
		CoreService.get_global_property_value('use.filing.number').to_s == "true" rescue false
	end 

	def generic_locations
		field_name = "name"

		Location.find_by_sql("SELECT *
			  FROM location
			  WHERE location_id IN (SELECT location_id
				             FROM location_tag_map
				              WHERE location_tag_id = (SELECT location_tag_id
				                     FROM location_tag
				                     WHERE name = 'Workstation Location'))
				 ORDER BY name ASC").collect{|name| name.send(field_name)} rescue []
	end

	def site_prefix
		site_prefix = CoreService.get_global_property_value("site_prefix") rescue false
		return site_prefix
	end

	def use_user_selected_activities
		CoreService.get_global_property_value('use.user.selected.activities').to_s == "true" rescue false
	end

	def tb_dot_sites_tag
		CoreService.get_global_property_value('tb_dot_sites_tag') rescue nil
	end

	def create_from_remote                                                        
		CoreService.get_global_property_value('create.from.remote').to_s == "true" rescue false
	end

	def concept_set(concept_name)
		concept_id = ConceptName.find(:first,:joins =>"INNER JOIN concept USING (concept_id)",
				                      :conditions =>["voided = 0 AND concept.retired = 0 AND name = ?",concept_name]).concept_id
		set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
		options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

		return options
	end

	def concept_set_diff(concept_name, exclude_concept_name)
		concept_id = ConceptName.find(:first,:joins =>"INNER JOIN concept USING (concept_id)",
		                  :conditions =>["voided = 0 AND concept.retired = 0 AND name = ?",concept_name]).concept_id
		set = ConceptSet.find_all_by_concept_set(concept_id, :order => 'sort_weight')
		options = set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

		exclude_concept_id = ConceptName.find(:first,:joins =>"INNER JOIN concept USING (concept_id)",
			                  :conditions =>["voided = 0 AND concept.retired = 0 AND name = ?", exclude_concept_name]).concept_id
		exclude_set = ConceptSet.find_all_by_concept_set(exclude_concept_id, :order => 'sort_weight')
		exclude_options = exclude_set.map{|item|next if item.concept.blank? ; [item.concept.fullname, item.concept.fullname] }

		final_options = (options - exclude_options)
		return final_options
	end

	def next_task(patient)
		session_date = session[:datetime].to_date rescue Date.today
		task = main_next_task(Location.current_location, patient, session_date)
		begin
			return task.url if task.present? && task.url.present?
			return "/patients/show/#{patient.id}" 
		rescue
			return "/patients/show/#{patient.id}" 
		end
	end

	# Try to find the next task for the patient at the given location
	def main_next_task(location, patient, session_date = Date.today)
		task = Task.new()
		
		if is_encounter_available(patient, 'DISCHARGE PATIENT', session_date)
			if !is_encounter_available(patient, 'DISCHARGE DIAGNOSIS', session_date)
				task.encounter_type = 'DISCHARGE DIAGNOSIS'
				task.url = "/encounters/new/discharge_diagnosis?patient_id=#{patient.id}"
			end
		end

		if is_encounter_available(patient, 'ADMIT PATIENT', session_date)
			if !is_encounter_available(patient, 'ADMISSION DIAGNOSIS', session_date)
				task.encounter_type = 'ADMISSION DIAGNOSIS'
				task.url = "/encounters/new/admission_diagnosis?patient_id=#{patient.id}"
			end
		end

		if task.encounter_type.nil?
			task.encounter_type = 'NONE'
			task.url = "/patients/show/#{patient.id}"
		end

		return task
	end

	def is_encounter_available(patient, encounter_type, session_date)
		is_vailable = false

		encounter_available = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
						                           patient.id,EncounterType.find_by_name(encounter_type).id, session_date],
						                           :order =>'encounter_datetime DESC',:limit => 1)
		if encounter_available.blank?
			is_available = false
		else
			is_available = true
		end

		return is_available	
	end

private

	def find_patient
		@patient = Patient.find(params[:patient_id] || session[:patient_id] || params[:id]) rescue nil
	end

end
